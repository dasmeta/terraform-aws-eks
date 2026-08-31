# Implementation Plan: Karpenter Stability Baseline

**Branch**: `009-karpenter-stability-baseline` | **Date**: 2026-08-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-karpenter-stability-baseline/spec.md`

## Summary

Extend the existing opinionated Karpenter wrapper so the controller survives the events it exists to handle, node replacement happens only on purpose, and voluntary consolidation stays out of business hours. Controller resources move to the values already validated in production with the CPU limit removed rather than raised; priority returns to `system-cluster-critical`; the non-deterministic instance-derived AMI lookup is replaced with a declarative `alias`; the IAM permission the upgraded interruption controller needs is granted; and new inputs add disruption windows, a drain ceiling, and opt-in on-demand protected capacity. Charts move to Karpenter 1.14.1 and karpenter-nodes 0.1.2.

Two decisions in research deliberately keep existing behaviour and say why: node expiry stays `Never` because expiry bypasses disruption budgets entirely, and pre-provisioned capacity buffers are deferred because this delivery already carries enough blast radius.

## Technical Context

**Language/Version**: Terraform (module `required_version` unchanged), AWS provider, Helm provider
**Primary Dependencies**: `terraform-aws-modules/eks/aws//modules/karpenter` v20.37.2 (pinned, upgrade out of scope); Karpenter charts `karpenter` and `karpenter-crd`; `dasmeta/helm` `karpenter-nodes`
**Storage**: N/A
**Testing**: native `terraform test` (`.tftest.hcl`) in `tests/`, plus `examples/eks-with-karpenter` and `examples/eks-with-karpenter-and-external-secret`
**Target Platform**: AWS EKS, Kubernetes 1.30+, module default `cluster_version` 1.34
**Project Type**: Opinionated Terraform wrapper module with submodules
**Constraints**: no manual state migration on upgrade; consumer interface stays minimal and grouped; no customer-identifying names in any Terraform artifact
**Scale/Scope**: 1 submodule, root wiring, 2 examples, new test directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Evidence |
| --- | --- | --- |
| I. Shared Constitution Source of Truth | PASS | No conflict found between repository-local guidance and shared governance for this change. |
| II. Terraform Module Workflow Skill Enforcement | PASS | `terraform-module-developer` invoked before any module edit; Speckit package created first; repository scope inspected; wrapper bias preserved; approval gates recorded below. |
| III. Wrapper-First Module Design and Safe Interfaces | PASS with approval | New inputs are grouped objects with optional attributes and inline per-field comments. No existing input changes between required and optional. The interface does widen — see Approval Gates. |
| IV. Evidence-First Verification | PASS | Native tests plus both examples; every claim in research is tied to an inspected file, an upstream document, or a recorded ticket. Limits of what can be verified without a cluster are stated explicitly in E15. |
| V. Documentation and Compatibility Discipline | PASS | Behavioural changes documented in the module upgrade guide in the same delivery, with migration guidance and rollback expectations. |
| Naming policy | PASS | All new names use neutral or `dasmeta` context. Existing touched content normalized. |
| Modern Capabilities Rule | Active, net-new abilities only | Disruption windows, drain ceiling, and protected capacity are net-new. Each uses the current supported mechanism rather than a deprecated one: `alias` selectors over instance-derived AMI IDs, `Balanced` consolidation, budget `reasons`. Capacity buffers classified **exempted-deferred** with reasoning in research E12. |

### Approval Gates

| Gate | Status |
| --- | --- |
| Breaking change: default behaviour changes for existing consumers on upgrade | **Approved by operator** — ship safe defaults now as a minor release rather than opt-in flags, because per-deployment retuning has repeatedly not happened. |
| Interface widening: new `controller_resources`, `disruption_windows`, `termination_grace_period`, `protected_node_pool`, `ami_alias` inputs | **Approved by operator** — direction was to fix the fleet at source. Widening is bounded to grouped optional attributes; no upstream pass-through is introduced. |
| Weakened default: instance-type constraints relaxed | **Approved by operator** — balanced disruption posture with broadened instance families was an explicit choice. |
| Out-of-scope upstream major upgrade | **Approved as split** — `terraform-aws-modules` v20 to v21 is a separate ticket. |
| Divergence from a production hotfix: dropping the controller CPU limit instead of raising it | **PENDING operator confirmation.** Recorded in research E1 and spec Assumptions. Implemented as recommended; explicitly flagged for the manual validation pass. |

## Project Structure

### Documentation (this feature)

```text
specs/009-karpenter-stability-baseline/
├── plan.md
├── spec.md
├── research.md          # E1..E15 decisions
├── data-model.md
├── quickstart.md
├── contracts/
│   └── module-interface.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit.tasks output
```

### Source Code (repository root)

```text
modules/karpenter/
├── main.tf              # controller resources; IAM statement; chart versions
├── variables.tf         # new grouped inputs, inline-commented
├── locals.tf            # alias-based node class; budgets; grace period; protected pool
├── data.tf              # instance-derived AMI lookup REMOVED
└── README.md            # regenerated inputs table

locals.tf                # priority class default -> system-cluster-critical
main.tf                  # pass ami_type-derived alias family; upgrade guide entry
variables.tf             # karpenter grouped input extended

tests/                   # NEW - native terraform tests, flat (not nested)
└── karpenter_defaults.tftest.hcl

examples/eks-with-karpenter/1-example.tf                      # demonstrates defaults
examples/eks-with-karpenter-and-external-secret/1-example.tf  # demonstrates protected pool
```

**Structure Decision**: Preserve the established repository layout. `required_providers` stays in `versions.tf`; no `providers.tf` is introduced. Tests go directly in `tests/` because `terraform test` does not discover nested per-case directories. `data.tf` in the submodule loses its instance lookup entirely rather than being left with a dead data source.

## Phase 2 Approach

1. Native tests first, run against the current module to establish which assertions fail today. Determinism (SC-003) is the one that must be shown failing before the fix.
2. Submodule changes: resources and IAM, then alias, then the new inputs.
3. Root wiring: priority class, alias family derivation.
4. Examples, docs, upgrade guide.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Interface widens by five inputs on a module whose principle is a minimal surface | Each corresponds to a behaviour the incident review shows must be tunable per deployment: controller sizing, disruption timing, drain ceiling, protected capacity, image pinning. Hard-coding any of them recreates the current defect, where the only fix is editing the module | Fewer inputs with opinionated fixed values was rejected because the current fixed values *are* the defect. Region-specific disruption windows and cluster-specific controller sizing cannot have one correct value |
| Plan-time precondition enforces only subnet count, not node count | Subnet count is knowable and provably blocking. Node count and their zone spread are not reliably knowable at plan time | Enforcing an unknowable condition would produce false failures; ignoring it entirely leaves today's silent Pending replica. Enforcing what is provable and documenting the rest is the honest split |
