# Implementation Plan: Upgrade ALB Controller

**Branch**: `002-upgrade-alb-controller` | **Date**: 2026-05-19 | **Spec**: `/Users/tmuradyan/projects/dasmeta/terraform-aws-eks/specs/002-upgrade-alb-controller/spec.md`
**Input**: Feature specification from `/specs/002-upgrade-alb-controller/spec.md`

## Summary

Upgrade the repository's AWS load balancer controller wrapper module to the `v3.3.0`
upstream chart/policy baseline, remove dead ALB log helper code, add controlled support
for custom chart/image sources and Pod Identity attachment patterns, preserve current root
module usage, and deliver a minimal example plus upgrade-focused documentation.

## Technical Context

**Language/Version**: HCL (Terraform `~> 1.3`)  
**Primary Dependencies**: HashiCorp `aws`, `helm`, and `kubernetes` providers; local
root wrapper module; local `modules/aws-load-balancer-controller`; Helm chart
`aws-load-balancer-controller`; AWS EKS IAM and Pod Identity APIs  
**Storage**: Repository-managed Terraform files and checked-in IAM policy JSON  
**Testing**: Terraform formatting/validation, docs sync, and example-based validation using
the dedicated `examples/eks-with-alb-controller` scenario  
**Target Platform**: AWS EKS clusters managed by this repository  
**Project Type**: Terraform infrastructure module (root wrapper + child wrapper module)  
**Performance Goals**: Keep controller deployment defaults suitable for cluster-critical
traffic management and avoid introducing source-selection or identity-binding ambiguity  
**Constraints**: Preserve backward-compatible root-module usage, keep wrapper inputs
opinionated rather than broad upstream pass-through, allow no built-in identity attachment
mode for externally managed Pod Identity, ignore `repository` when a direct chart package
endpoint is used, update docs/examples in the same scope, and stay within repository-only
changes  
**Scale/Scope**: Root `alb_load_balancer_controller` interface, child module files,
module README, root README/docs surfaces, and a new dedicated example under
`examples/eks-with-alb-controller`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Shared governance alignment**: PASS. Local constitution is used together with the
  shared constitution source; no conflict identified at planning time.
- **Terraform-module-developer workflow**: PASS. Repository-scope inspection, wrapper-first
  interface review, Speckit package presence, and approval-gate scan are included.
- **Speckit evidence / module-change gate**: PASS. The feature package exists under
  `specs/002-upgrade-alb-controller/` with `spec.md`, `plan.md`, and downstream planning
  artifacts generated in this workflow.
- **Wrapper preservation**: PASS with guardrail. The plan keeps the root module as the
  opinionated consumer interface and limits new inputs to narrowly scoped optional release,
  image, and identity settings rather than exposing a broad Helm chart pass-through.
- **Breaking change scan**: PASS with compatibility constraint. Dead implementation paths
  may be removed, but existing root-module usage and deprecated no-op fields must not break
  current callers without explicit approval.
- **Evidence-first verification**: PASS. Implementation must include formatting,
  validation, docs alignment, and dedicated example checks.
- **Documentation and compatibility discipline**: PASS. Module docs, example docs, and
  upgrade guidance are part of the delivery scope.

## Project Structure

### Documentation (this feature)

```text
specs/002-upgrade-alb-controller/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── aws-load-balancer-controller-module-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
alb-ingress-controller.tf
variables.tf
README.md
examples/eks-with-alb-controller/
├── 0-setup.tf
├── 1-example.tf
├── README.md
└── http-echo-alb-controller.yaml
modules/aws-load-balancer-controller/
├── main.tf
├── variables.tf
├── iam.tf
├── iam-policy.json
├── versions.tf
└── README.md
```

**Structure Decision**: Keep the existing root wrapper and child module boundaries. Apply
behavioral changes in the child module, preserve the root wrapper as the supported consumer
interface, remove inactive child-module files/subdirectories, and add one new example
directory without broader repository restructuring.

## Phase 0: Outline & Research

- Confirm the upstream baseline for this change:
  - Helm chart `aws-load-balancer-controller` version `3.3.0`
  - Matching IAM policy source under upstream tag `v3.3.0`
- Compare the checked-in IAM policy against the upstream `v3.3.0` policy to identify the
  permission drift that the refreshed file must absorb.
- Decide the wrapper-safe interface shape for new source and image controls:
  - narrow optional fields grouped under the existing root object
  - child-module variables that remain opinionated and deterministic
- Decide identity binding behavior:
  - legacy service-account annotation support remains available
  - built-in Pod Identity association support is added
  - no built-in attachment mode remains valid for externally managed Pod Identity
  - conflicting dual-attachment configuration fails validation
- Determine compatibility treatment for current deprecated ALB log fields so the root
  module does not break existing callers while dead implementation is removed.

Output: `research.md` with explicit decisions and alternatives.

## Phase 1: Design & Contracts

- Define data model for:
  - controller release source selection
  - controller image override behavior
  - identity binding mode and validation rules
  - policy artifact lifecycle
  - dedicated example validation surface
- Define module behavior contract:
  - source precedence and ignored fields
  - identity mode combinations and allowed states
  - backward-compatible root wrapper expectations
  - deprecated input handling
  - documentation and example obligations
- Draft quickstart for:
  - refreshing the policy artifact from the upstream tagged source
  - validating the upgraded module via the dedicated example
  - checking docs and Terraform validation locally

Outputs:
- `data-model.md`
- `contracts/aws-load-balancer-controller-module-contract.md`
- `quickstart.md`

## Post-Design Constitution Re-check

- Shared governance conflict: none found at planning time.
- Interface widening required: limited and justified. The plan adds narrowly scoped
  optional fields for release/image/identity behavior instead of broad chart pass-through.
- Breaking changes expected: none approved. Deprecated root inputs tied to removed ALB log
  code should remain accepted or explicitly documented as no-op unless approval is granted
  for removal.
- Required explicit approvals: none at planning stage. If implementation reveals that
  backward compatibility for deprecated root inputs cannot be preserved safely, stop and
  request approval before changing the interface.

## Complexity Tracking

No constitution violations requiring justification at planning stage.
