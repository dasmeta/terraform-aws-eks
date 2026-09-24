# Karpenter Stability Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Implementation complete; live validation partially complete. Scenario
1 passed end to end. Scenarios 2 and 3 are outstanding — see the last section.

**Goal:** Make spot capacity and consolidation safe to run by default, so that
reclamation and cost optimisation stop causing user-visible disruption.

**Architecture:** Extend the existing opinionated wrapper at `modules/karpenter`
and its root wiring. Behavioural settings live in the existing grouped
`resource_configs_defaults` / `resource_configs` buckets rather than new
top-level inputs, so the consumer interface does not widen.

**Tech Stack:** Terraform >= 1.3, AWS provider, Helm provider, Terraform native
tests, Karpenter 1.14 CRDs.

**Spec:** `docs/superpowers/specs/2026-08-31-karpenter-stability-baseline-design.md`

## Global Constraints

- The consumer interface stays minimal and grouped. Every grouped and nested
  field carries an inline comment. No input changes between required and optional.
- Upgrading `terraform-aws-modules/eks` 20.37.2 -> 21.x is out of scope.
- No customer-identifying names in any Terraform artifact, doc or example. This
  module is public and the work draws on real client clusters.
- Applying the new defaults must not require manual state manipulation.

---

### Task 1: Controller survives a scale event

**Files:** `modules/karpenter/variables.tf`, `modules/karpenter/locals.tf`,
`modules/karpenter/main.tf`, `locals.tf`

- [x] Add `controller_resources`: requests `250m`/`512Mi`, memory limit `1Gi`,
      **no CPU limit**
- [x] Build the resource block so an unset CPU limit is absent from the rendered
      values rather than rendering as null
- [x] Restore `system-cluster-critical` priority in root `locals.tf`
- [x] Add a plan-time precondition failing when replicas >= 2 with < 2 subnets
- [x] Native tests for each

### Task 2: Deterministic AMI selection

**Files:** `modules/karpenter/locals.tf`, `modules/karpenter/data.tf`

- [x] Replace the `aws_instances...ids[0]` lookup with the declarative `alias`
      form, family derived from the declared node group `ami_type`
- [x] Keep a full `amiSelectorTerms` override that wins over the alias
- [x] Remove the now-unused data source

### Task 3: Disruption windows and consolidation

**Files:** `modules/karpenter/variables.tf`, `modules/karpenter/locals.tf`

- [x] Render NodePool `budgets` with `schedule`, `duration`, `reasons`
- [x] Default: block `Drifted` and `Underutilized` 06:00-18:00 UTC Mon-Fri,
      always permit `Empty`, alongside a `10%` baseline
- [x] `Balanced` consolidation, `consolidateAfter` 3m -> 15m (1m for GPU, which
      is costly enough that a minute longer is real money)
- [x] Per-pool disruption settings win field by field over the class defaults

### Task 4: Reduce reclamation exposure

- [x] Widen requirements to CPU 2-32, memory 2-128Gi
- [x] Add `instance-category In [c, m, r]`, generation > 4
- [x] Leave `expireAfter` at `Never`, with the reasoning documented

### Task 5: IAM for the upgraded interruption controller

**Files:** `modules/karpenter/main.tf`

- [x] Grant `ec2:DescribeInstanceStatus` and `iam:ListInstanceProfiles`
- [x] **Via a separate `aws_iam_policy` attached through `iam_role_policies`**,
      not `iam_policy_statements` — the upstream document has no usable headroom

### Task 6: Interface minimisation

- [x] Remove `protected_node_pool`, `disruption_windows`,
      `termination_grace_period` and `ami_alias` as top-level inputs; express
      each through the existing grouped buckets
- [x] Convert `resource_configs_defaults` to typed nested objects with
      per-field `optional()` defaults, so a sibling field does not erase its peers
- [x] Root validation rejecting top-level keys other than `default` / `gpu` —
      Terraform silently drops unknown attributes during object conversion, so a
      mis-nested `limits` would otherwise fall back to the module default at 90x
      the intended value

### Task 7: System node isolation

**Files:** `variables.tf`, `locals.tf`

- [x] Taint managed node groups `CriticalAddonsOnly=true:NoSchedule` by default,
      only when Karpenter is enabled
- [x] Node group defaults: min/desired 2, max 4, `t3.medium`, on-demand, AL2023
- [x] A node group declaring its own taints is left exactly as written

### Task 8: Versions

- [x] Karpenter and CRD charts `1.9.0` -> `1.14.1`, CRDs first
- [x] `karpenter-nodes` `0.1.0` -> `0.1.2`

### Task 9: Assessment tooling and delivery guide

**Files:** `scripts/eks-assess.sh`, `scripts/eks-config-lint.sh`,
`docs/eks-stability-guide.md`

- [x] Zero-argument, read-only cluster assessment discovering cluster, region
      and account from the kube context
- [x] Static config linter for YAML that fails loudly on unparseable files
- [x] Phased delivery guide, AI- and human-readable, with a per-region window table
- [x] CI guard rejecting absolute local paths in committed configuration

### Task 10: Upgrade documentation

- [x] Record every behavioural change, what changes without action, and what an
      operator must decide

---

## Live validation

- [x] **Scenario 1** — fresh cluster from `examples/eks-with-karpenter-recommended`.
      Passed. Confirmed on a live cluster: controller at the new requests with no CPU
      limit and headroom to spare, `system-cluster-critical`, two replicas across
      two AZs, `al2023@latest` alias, `Balanced`/`15m`, budgets carrying the
      window, `c6a.large` spot and `c5a.large` on-demand selected rather than
      burstable, and no zero-eviction PDBs. The disruption window was verified
      directly against `karpenter_nodepools_allowed_disruptions`: a pool carrying
      the window reported no allowed disruptions for the reasons it names, while a
      pool without one allowed them at the same moment.
- [x] **Scenario 4** — kubernetes version upgrade on the same cluster. Passed. The managed node group
      drained and upgraded with no eviction failures, which is the PodDisruptionBudget requirement tested
      end to end. Raising the control plane drifted the karpenter fleet and the disruption window held the
      roll, blocking exactly the reasons it names while a pool without a window allowed all three.

- [ ] **Scenario 2** — in-place upgrade from the released version. Exercises the
      CRD chart upgrade and the system-node taint landing on an existing node
      group, neither of which a clean install touches. Now also exercises the
      kyverno uninstall, since that default flipped to off.
- [ ] **Scenario 3** — assessment run against a real cluster.

## Defects found by validation, not by review

- The controller IAM policy exceeded the 6144-character cap, so it was never
  created and Karpenter could launch nothing. Presented as unrelated Helm
  releases timing out.
- Both ingress replicas landed on one spot node in our own recommended example,
  which is the originating incident reproduced by the reference configuration.
  Resolved by serving ingress with an ALB instead of an in-cluster controller.
- The example's ALB ingresses would not have provisioned at all: the chart's
  default listen-ports include HTTPS with no certificate to match.
- external-dns shipped with no resource requests, so Karpenter sized nodes as
  though it were free.
