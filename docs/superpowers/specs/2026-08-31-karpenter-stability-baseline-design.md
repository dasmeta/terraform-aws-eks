# Karpenter Stability Baseline Design

**Ticket:** DMVP-10430 (case group A)

## Context

A production API served bursts of 502 and 504 responses when four spot nodes
were reclaimed while the Karpenter controller was unavailable. The interruption
notices went unprocessed and the nodes were never drained. A fleet-wide review
tied roughly 35 incidents to a small set of causes, several of which were live
defects in this module rather than per-cluster misconfiguration.

The causal chain in the originating incident: the controller ran with hard-coded
limits of `200m` CPU and `256Mi` memory, which caused OOMKills roughly every six
minutes; with the controller restarting, interruption messages sat in the queue
for 179 seconds against a 120-second notice; nodes were reclaimed before any
drain began; traffic kept arriving at pods on machines that were already gone.

## Goal

Make spot capacity and consolidation safe to run by default, so that reclamation
and cost optimisation stop being a source of user-visible disruption.

## What shipped

### The controller stays alive

`controller_resources`, defaulting to requests of `250m` CPU and `512Mi` memory
with a **memory limit of `1Gi` and no CPU limit**. The CPU limit is dropped
rather than raised: a cap throttles the controller during exactly the scale and
reclamation events it exists to react to, so a limit guarantees the failure mode
under load. Memory keeps a limit because unbounded growth is a real node-level
risk, whereas CPU contention is handled by the scheduler through the request.

Priority returns to `system-cluster-critical` (2,000,000,000). The root module
had been substituting a local class valued 1,000,000, which demoted the
controller below every genuinely critical component and forfeited kubelet
critical-pod protection — so under node pressure the component responsible for
*adding* capacity became a preemption candidate.

A plan-time precondition fails when more than one replica is requested with
fewer than two subnets. Two replicas require two non-Karpenter nodes in two
availability zones, because the upstream chart combines required hostname
anti-affinity with zone spread and a node affinity excluding Karpenter's own
nodes. Previously an unsatisfiable request left a replica silently Pending: the
cluster looked highly available and was not.

### Capacity changes happen on purpose

AMI selection moves to the declarative `alias` form (`family@version`), with the
family derived from the declared managed node group `ami_type`. It previously
resolved an arbitrary running instance via `aws_instances...ids[0]`, so an
unrelated apply could change the fleet's target image and mark every node
drifted at once.

`@latest` means node replacement is continuous and unattended — Karpenter
re-checks about every minute and starts a paced roll when AWS publishes a new
image, with no Terraform run involved. That is safe because drift is *voluntary*
disruption, so budgets and windows apply to it.

### Voluntary disruption is confined to safe hours

NodePool budgets carry `schedule`, `duration` and `reasons`. The default blocks
`Drifted` and `Underutilized` from 06:00 to 18:00 UTC Monday to Friday, and
always permits `Empty` — removing an empty node disrupts nothing, so blocking it
would forgo free savings for no safety gain.

Budgets gate voluntary disruption only. They never delay provider reclamation,
so this is a cost-optimisation window, not a defence against spot interruption.

Schedules are evaluated in **UTC only** — Karpenter has no timezone support — so
the default suits central Europe and is wrong elsewhere. Multiple budgets
resolve most-restrictive-wins.

Consolidation defaults to `Balanced` with `consolidateAfter` raised from `3m` to
`15m`. The old window meant a brief utilisation dip immediately triggered node
removal, which the review repeatedly ties to replicas being evicted too close
together.

### Reduced exposure to reclamation

Default instance requirements widen to CPU 2–32 and memory 2–128 GiB and add
`instance-category In [c, m, r]` with generation > 4. Interruption frequency
falls as instance-type flexibility rises. The category filter exists because
without it burstable was often cheapest, and clusters were repeatedly landing on
`t3.2xlarge`: burstable throttles under sustained load, which presents as
latency that looks like an application fault, and sits in the most contended
spot pools.

Protected on-demand capacity is configured as an **ordinary node pool** with an
on-demand capacity-type requirement and a taint. Workloads opt in by tolerating
the taint *and* selecting on-demand — the toleration alone only makes the nodes
eligible.

## Decisions reversed during implementation

Recorded because the reasoning matters more than the outcome.

**`terminationGracePeriod` defaults to unset, not `24h`.** The original design
treated it as a stuck-node safety net. It does more than bound a drain already
underway: it makes a node **eligible for drift** even when it hosts pods with
blocking PodDisruptionBudgets or the `karpenter.sh/do-not-disrupt` annotation,
and force-deletes those pods when it elapses. That converts both protections
from a guarantee into a delay. A workload marked always-up now stays up, and its
node keeps an older AMI until a human moves it. Assessment section D4 lists such
nodes and names what holds them.

**No dedicated inputs for windows, grace period, AMI alias or protected pools.**
Each was initially a separate top-level variable. All were folded into the
existing `resource_configs_defaults` and `resource_configs` buckets. Standard
node pools already express protected capacity and more — labels, multiple taints,
a custom node class — and a pool declaring its own `budgets` is naturally
excluded from the windows, which is what such a pool wants. Every removal
surfaced a latent bug in the code that had special-cased it.

**Extra IAM actions go in a separate managed policy, not
`iam_policy_statements`.** The upstream controller document already measures
5966 characters against a 6144 cap for a 30-character cluster name, and the
cluster name appears in it 16 times — so a name 11 characters longer exhausts
the headroom with nothing added by us. Going over does not degrade gracefully:
the policy fails to create, the controller holds no permissions, and Karpenter
launches nothing, which surfaces as unrelated workloads hanging with nowhere to
schedule. This was found by a failed end-to-end apply, not by review.

## Deliberately unchanged

**`expireAfter` stays `Never`.** Expiry is not gated by disruption budgets, so
any finite value would replace nodes unpaced and outside the protected window —
precisely what this work exists to prevent. Switching an existing fleet to a
finite value would also expire every older node at once. Patching is handled by
budget-paced AMI drift instead.

**CapacityBuffers (Karpenter 1.14) are not adopted.** They add another CRD on
top of a five-minor-version upgrade whose whole purpose is reducing risk, and
the benefit cannot be measured until the baseline is proven.

## Versions

Karpenter `1.9.0` -> `1.14.1`, CRD chart first; `karpenter-nodes` `0.1.0` ->
`0.1.2`. This leaves the 1.9 LTS line deliberately, in exchange for
instance-status health checks in the interruption controller (1.12+) and
`Balanced` consolidation.

Upgrading the upstream `terraform-aws-modules/eks` karpenter submodule from
20.37.2 to 21.x is **out of scope** and tracked separately.

Three concrete findings for that ticket, discovered while validating this one:

- **It gates the AWS provider major version.** Both the eks module and its
  karpenter submodule at 20.37.2 require `aws >= 5.95, < 6.0.0`. Nothing in this
  repository can move to provider 6.x until that upgrade lands, and no change to
  our own constraints helps -- only 6 of our files cap at `< 6.0.0` and none of
  them is what binds.
- **It gates the VPC module.** `dasmeta/vpc` 1.1.0 pulls
  `terraform-aws-modules/vpc` 6.6.0, which requires `aws >= 6.28`. That is
  mutually unsatisfiable with the line above, so the vpc module stays at 1.0.1
  and its deprecated `aws_eip.vpc` warning stays with it. The warning is
  cosmetic and changes nothing about what is created.
- **Two of our modules need real code changes, not just a constraint bump.**
  `modules/ebs-csi` and `modules/efs-csi` use `aws_iam_role.managed_policy_arns`,
  which provider 6 removes. They need `aws_iam_role_policy_attachment` instead.
  Both already emit a deprecation warning on `terraform validate` today, which is
  where this surfaced.
- The `iam_policy_statements` workaround in `modules/karpenter` can be deleted at
  the same time: `iam:ListInstanceProfiles` and `ec2:DescribeInstanceStatus` are
  both granted upstream from v21.15.1+.

## Verification

Native `.tftest.hcl` tests for assertions that need no cloud credentials, plus
three live scenarios: a fresh cluster from
`examples/eks-with-karpenter-recommended`, an in-place upgrade from the released
version, and an assessment run against a real cluster. `scripts/eks-assess.sh`
is read-only and zero-argument, discovering cluster, region and account from the
current kube context.
