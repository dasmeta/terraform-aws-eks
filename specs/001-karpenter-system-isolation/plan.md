# Implementation Plan: Karpenter System Isolation

**Branch**: `001-karpenter-system-isolation` | **Date**: 2026-04-08 | **Spec**: `/Users/tmuradyan/projects/dasmeta/terraform-aws-eks/specs/001-karpenter-system-isolation/spec.md`
**Input**: Feature specification from `/specs/001-karpenter-system-isolation/spec.md`

## Summary

Enforce dedicated system-node isolation so non-critical workloads cannot schedule on the
on-demand system node pool, ensure Karpenter uses the highest predefined priority class,
and keep multi-replica Karpenter availability as default behavior with explicit validation.

## Technical Context

**Language/Version**: HCL (Terraform `~> 1.3`)  
**Primary Dependencies**: `terraform-aws-modules/eks`, local `modules/karpenter`,
local `modules/priority-class`, Helm-delivered Karpenter charts  
**Storage**: N/A  
**Testing**: Terraform validation + repository example-based integration tests
(`examples/*`, `modules/*/tests/*`)  
**Target Platform**: AWS EKS clusters provisioned by this module  
**Project Type**: Terraform infrastructure module (wrapper module)  
**Performance Goals**: Preserve autoscaling controller availability during node churn and
single pod failure  
**Constraints**: Backward-compatible defaults, no broad interface widening, no governance
conflicts with shared constitution, avoid non-critical pods on system nodes by default  
**Scale/Scope**: Root module + `modules/karpenter` + `examples/eks-with-karpenter`
documentation and validation surface

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Shared governance alignment**: PASS. Plan follows local constitution and references
  shared governance as authoritative for cross-repository rules.
- **Terraform-module-developer workflow**: PASS. Scope includes repository inspection,
  wrapper-first behavior, and no implicit interface widening.
- **Approval gate scan**: PASS. No required breaking change identified for default-targeted
  updates. If contract drift is discovered during implementation, stop for approval.
- **Evidence-first verification**: PASS. Plan includes explicit validation steps and
  docs/example synchronization.
- **Documentation and compatibility discipline**: PASS. Plan includes README/example and
  test alignment with behavior changes.

## Project Structure

### Documentation (this feature)

```text
specs/001-karpenter-system-isolation/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── karpenter-system-scheduling-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
main.tf
variables.tf
locals.tf
README.md
examples/eks-with-karpenter/
├── 0-setup.tf
└── 1-example.tf
modules/karpenter/
├── main.tf
├── variables.tf
├── locals.tf
└── outputs.tf
modules/priority-class/
├── main.tf
└── variables.tf
```

**Structure Decision**: Keep existing module boundaries and implement behavior through
targeted updates in root + Karpenter module + example paths. No repository restructuring.

## Phase 0: Outline & Research

- Confirm current behavior for:
  - Karpenter replica default and override path (`var.karpenter.configs`)
  - Current priority class support path between root module and Karpenter chart values
  - Existing system node taint/toleration patterns in examples
- Validate whether highest priority class is available by default from priority-class
  module and how Karpenter should reference it.
- Define compatibility-safe fallback behavior when priority class is absent.

Output: `research.md` with explicit decisions and alternatives.

## Phase 1: Design & Contracts

- Define data model for:
  - System-node scheduling policy signals
  - Workload criticality mapping
  - Karpenter priority class binding
  - Karpenter replica baseline
- Define behavioral contract:
  - Non-critical workloads excluded from system node pool by default
  - Karpenter on highest predefined priority class
  - Default >=2 replicas and expected failover behavior
- Draft quickstart for validation flow in example cluster.

Outputs:
- `data-model.md`
- `contracts/karpenter-system-scheduling-contract.md`
- `quickstart.md`

## Post-Design Constitution Re-check

- Shared governance conflict: none found
- Interface widening required: none expected (use existing config objects)
- Breaking changes expected: none expected (preserve existing behavior where already present)
- Required explicit approvals: none at planning phase

## Complexity Tracking

No constitution violations requiring justification at planning stage.
