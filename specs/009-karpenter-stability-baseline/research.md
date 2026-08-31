# Phase 0 Research: Karpenter Stability Baseline

**Feature**: `specs/009-karpenter-stability-baseline` | **Date**: 2026-08-31

## E1 — Controller resources

**Decision**: New `controller_resources` input. Defaults: requests `250m` CPU / `512Mi` memory, limits **memory `1Gi` only, no CPU limit**.

**Rationale**: `modules/karpenter/main.tf` hard-codes limits of `200m`/`256Mi`. Those exact values were diagnosed in the field as causing CPU throttling and OOMKills during scale-up; the corrected values were measured per deployment but never landed here, so every clean install still ships the configuration that produced the incident. The upstream chart deliberately ships `controller.resources: {}` and declines to guess.

**The CPU limit is dropped, not raised.** A CPU limit throttles the controller during exactly the scale and reclamation events it exists to react to — a slow controller is the failure mode, and a cap guarantees it under load. A memory limit is retained because unbounded memory growth is a genuine node-level risk, whereas CPU contention is handled by the scheduler through the request.

**Divergence flagged**: a per-deployment hotfix set a `1000m` CPU limit. This decision knowingly differs and is called out for operator confirmation rather than adopted silently.

## E2 — Controller priority

**Decision**: Default to `system-cluster-critical`, the upstream chart default. Remains overridable.

**Rationale**: root `locals.tf` currently substitutes the priority-class submodule's highest class, valued `1,000,000`, for the chart's `system-cluster-critical`, valued `2,000,000,000`. The substitution demotes the controller below every genuine system-critical component and forfeits kubelet critical-pod protection, so under node pressure the component responsible for adding capacity is a preemption candidate. This was introduced by earlier system-isolation work and is a regression.

## E3 — Deterministic machine image selection

**Decision**: Replace the instance-derived `amiSelectorTerms` with the declarative `alias` form. The family is derived from the **declared** managed node group `ami_type`, and the version defaults to `latest`. Both the alias and the full `amiSelectorTerms` remain overridable.

**Rationale**: `modules/karpenter/data.tf` resolves `aws_instances...ids[0]` — an arbitrary running instance — and feeds its AMI into `amiSelectorTerms`. Which instance answers is not stable, so an unrelated apply can change the fleet's target image and mark every node drifted at once. This is the undocumented "two separate waves of change" already recorded in the module README.

`alias` accepts `family@version` (for example `al2023@latest` or `al2023@v20240807`) and makes `amiFamily` implicit. With a pinned version there is no drift at all; with `latest`, a new AMI release drifts out-of-date nodes — but that drift **is** paced by disruption budgets and windows, so it becomes a controlled, off-peak roll rather than a surprise.

**No OS-family migration for default deployments**: `variables.tf:60` already defaults managed node groups to `AL2023_x86_64_STANDARD` and `cluster_version` defaults to `1.34`, so the existing detection already resolves to AL2023. Deriving the alias family from the declared `ami_type` rather than a guess preserves the family for AL2 deployments too.

| Declared `ami_type` | Alias family |
| --- | --- |
| `AL2023_*` | `al2023` |
| `AL2_*` | `al2` |
| `BOTTLEROCKET_*` | `bottlerocket` |

**Alternatives considered**: pinning a specific version by default was rejected because it leaves nodes unpatched until someone remembers to bump it, and the module has no mechanism to remind anyone. Keeping the instance lookup but sorting deterministically was rejected because it still changes when the sampled node is replaced.

**Scope boundary**: the GPU node class keeps its current `most_recent = true` AMI lookup. It has the same drift characteristic and should move to an alias too, but it is opt-in, exercised by a separate example, and changing it is separable risk. Recorded as follow-up rather than silently bundled.

## E4 — IAM for the upgraded interruption controller

**Decision**: Add `ec2:DescribeInstanceStatus` through the existing `iam_policy_statements` escape hatch already used for `iam:ListInstanceProfiles`.

**Rationale**: the pinned upstream module v20.37.2 grants `AllowRegionalReadActions` without it (`policy.tf:145-153`, verified). Karpenter 1.12+ requires it for the EC2 instance-status health checks in the interruption controller — the feature most directly relevant to this incident. Without it the new code path fails with AccessDenied and the capability is silently absent.

`ec2:DescribePlacementGroups` (required by 1.11+) is **not** added: it is needed only when placement groups are used, which this module does not configure. Adding unused permissions widens the role for no benefit.

## E5 — Controller replica fitness

**Decision**: A precondition fails the plan when more than one replica is requested but fewer than two subnets are supplied. The node-count requirement is documented, not enforced, because the module cannot see it.

**Rationale**: the upstream chart combines required hostname anti-affinity, `DoNotSchedule` zone spread, and a node affinity excluding Karpenter's own nodes. Two replicas therefore require two non-Karpenter nodes in two availability zones. Today an unsatisfiable request produces a silently Pending replica — the cluster appears highly available and is not.

Subnet count is knowable at plan time and is a genuine hard blocker, so it is enforced. Managed node group instance count and their zone distribution are not reliably knowable at plan time, so they are documented with the diagnostic commands instead. Failing loudly on what we can prove beats guessing at what we cannot.

## E6 — Node expiry stays disabled, deliberately

**Decision**: `expireAfter` remains `Never` by default, with the reasoning documented. This is a considered decision, not an oversight.

**Rationale**: **expiry is not gated by disruption budgets.** Karpenter's documentation is explicit that budgets "do not prevent Karpenter from terminating expired nodes". Setting a finite expiry would therefore create a class of node replacement that ignores both the disruption budget and the protected time window this feature adds — replacement could run unpaced during peak traffic, which is precisely what the feature exists to prevent. Worse, switching an existing fleet from `Never` to any finite value would instantly mark every node older than that value as expired, all at once and unpaced.

Patching is instead handled by AMI drift through the `latest` alias (E3), which **is** budget-paced and window-aware, and achieves the same security outcome under control.

## E7 — Instance type breadth

**Decision**: Widen the default requirements to CPU 2–32 and memory 2–128 GiB, keeping generation greater than 2, `amd64`, and both capacity types.

**Rationale**: current defaults cap CPU below 9 and memory below ~32 GiB, which narrows the candidate pool sharply. Spot interruption frequency falls as instance-type flexibility rises, and spot-to-spot consolidation requires substantial flexibility to be available at all. The lower bounds are kept: nodes below 2 CPU or 2 GiB struggle to run the kubelet plus system daemons, which is a real constraint rather than a preference. Architecture stays `amd64` because changing it would require every consumer image to be multi-arch.

## E8 — Consolidation policy

**Decision**: `Balanced` with `consolidateAfter` raised from `3m` to `15m`.

**Rationale**: `Balanced` weighs cost saving against disruption instead of consolidating whenever a cheaper arrangement exists, and is available in the target version. The `3m` window meant a brief dip in utilisation immediately triggered node removal, which the incident review repeatedly ties to replicas being evicted too close together.

## E9 — Disruption windows

**Decision**: New `disruption_windows` input rendering NodePool `budgets` entries with `schedule`, `duration`, and `reasons`. Default blocks `Drifted` and `Underutilized` from 06:00 to 18:00 UTC, Monday to Friday, leaving `Empty` always permitted.

**Rationale**: removing an empty node disrupts nothing, so blocking it would forgo free savings for no safety gain. Budgets are voluntary-only and never delay provider reclamation, so this is genuinely a cost-optimisation window rather than a safety mechanism against spot interruption.

**Documented constraints**: schedules are evaluated in UTC only — Karpenter states "Timezones are not currently supported" — so the default is offset by an hour across European daylight saving and is wrong outright for other regions. Multiple budgets resolve most-restrictive-wins.

## E10 — Drain upper bound

**Decision**: Expose `terminationGracePeriod`, defaulting to `24h`.

**Rationale**: without it a single pod that resists termination keeps a node in a terminating state indefinitely, blocking the capacity change. The value is deliberately long: this is a stuck-node safety net, not a shutdown budget. It matters that once it expires Karpenter deletes remaining pods **regardless of disruption budgets**, so a short value would itself become a source of disruption. A day is long enough never to fire in normal operation and short enough to unwedge a node without manual intervention.

## E11 — Protected capacity

**Decision**: Opt-in on-demand node pool, disabled by default, carrying a taint so only workloads that tolerate it land there. Uses `WhenEmpty` consolidation and is excluded from voluntary disruption windows.

**Rationale**: repeatedly implicated where reclaimed capacity removed ingress or monitoring and thereby degraded the diagnosis of every co-occurring incident. Opt-in because it is on-demand capacity with a real cost, and creating it unconditionally would raise spend for every consumer.

## E12 — Pre-provisioned spare capacity: defer

**Decision**: **Defer.** Do not adopt CapacityBuffers in this delivery. Recorded with reasoning, satisfying FR-021.

**Rationale**: it graduated to beta in the target version and introduces an additional custom resource definition. This delivery already carries a five-minor-version autoscaler upgrade, a definitions upgrade with historically manual steps, and a set of behavioural default changes. Adding a new resource kind on top increases the blast radius of a change whose entire purpose is to reduce risk, and its benefit cannot be measured until the rest of the baseline is proven. Revisit once the baseline is validated in a live cluster.

## E13 — Autoscaler version

**Decision**: `1.9.0` to `1.14.1`, definitions chart first.

**Rationale**: 1.9 is the designated long-term-support line, so this leaves LTS. The trade buys the three capabilities this incident specifically needs: instance-status health checks in the interruption controller (1.12), `Balanced` consolidation, and the pre-provisioned capacity API (deferred per E12 but available). Upgrade notes across 1.10 to 1.14 record no breaking changes beyond the IAM additions in E4.

**Risk**: the definitions chart has previously required manual patch commands, recorded in the module README. This is the highest-risk step for existing consumers and cannot be validated by a clean install; it needs an in-place upgrade over a cluster already running 1.9.0.

## E14 — Node configuration package

**Decision**: default `0.1.0` to `0.1.2`.

**Rationale**: the module ships a default older than the chart it owns. Both node pool and node class templates are `toYaml` passthroughs, so budgets, `terminationGracePeriod`, and the alias form all render without any chart change — the version bump is alignment, not a dependency of this feature.

## E15 — Verification approach

**Decision**: native `.tftest.hcl` tests in `tests/` for assertions that need no cloud credentials, plus example-based validation through both Karpenter examples.

**Rationale**: repository convention and the module-developer standard both call for native tests placed directly in `tests/`, not nested in per-case subdirectories where `terraform test` never finds them. Local Terraform is 1.13.0, comfortably above the 1.6 floor native tests require. The module's `required_version` floor is **not** raised, since doing so would break consumers on older Terraform for no functional gain; tests are a repository concern, not a consumer one.

Assertions that genuinely need AWS (actual node provisioning, drain behaviour, interruption handling) belong to the live-cluster test tiers and are out of scope for this phase.
