# Implementation Plan: Linkerd CRD Chart Configuration

**Branch**: `005-linkerd-crds-config` | **Date**: 2026-07-28 |
**Spec**: `specs/005-linkerd-crds-config/spec.md`

## Summary

Add an optional `configs_crds` map to the existing root `linkerd` object and
the Linkerd child module, forward it unchanged, and encode it into the
`linkerd-crds` Helm release values. Preserve all existing defaults and document
the explicit `installGatewayAPI` use case.

## Technical Context

**Language/Version**: Terraform >= 1.3.0  
**Primary Dependencies**: HashiCorp Helm provider >= 2.0, Linkerd Helm charts  
**Storage**: N/A  
**Testing**: Terraform native tests, `terraform validate`, `terraform fmt`  
**Target Platform**: AWS EKS and Kubernetes  
**Project Type**: Terraform wrapper module with a nested Linkerd submodule  
**Performance Goals**: N/A; configuration-only plan-time behavior  
**Constraints**: Backward-compatible interface; no default Gateway API install  
**Scale/Scope**: Root EKS module, `modules/linkerd`, one Linkerd example

## Constitution Check

- The change stays within the existing Linkerd responsibility boundary.
- `configs_crds` belongs in the existing grouped `linkerd` object.
- The new attribute is optional and defaults to `{}`, preserving omission
  behavior.
- The interface is a bounded chart-values pass-through consistent with existing
  `configs` and `configs_viz`; it does not expose unrelated Helm internals.
- Documentation, example, and test coverage are included.
- No provider or Terraform version constraint changes are required.
- Modern capability classification: **supported**. The selected Linkerd CRD
  chart already supports CRD values, including `installGatewayAPI`; this change
  only makes the existing supported chart interface reachable.
- Shared governance source:
  `/Users/juliaaghamyan/.codex/constitution/skills/terraform-module-developer`.
- Module-change gate: expected to pass because this package contains
  `spec.md`, `plan.md`, and `tasks.md`.
- Speckit bootstrap note: `create-new-feature.sh` could not re-check out the
  branch already attached to the isolated worktree. The package was created
  from repository templates on the current matching branch.

## Project Structure

```text
variables.tf
main.tf
modules/linkerd/
├── main.tf
├── variables.tf
├── README.md
└── tests/
    └── configs_crds.tftest.hcl
examples/eks-with-linkerd/
└── 1-example.tf
specs/005-linkerd-crds-config/
├── spec.md
├── plan.md
└── tasks.md
docs/superpowers/
├── specs/2026-07-28-linkerd-crds-config-design.md
└── plans/2026-07-28-linkerd-crds-config.md
```

**Structure Decision**: Preserve the repository's established root-module and
nested-module layout. Add focused native test coverage beside the Linkerd
submodule and update the existing Linkerd example instead of creating a new
example tree.

## Current State and Standards Assessment

- Starting module path: repository root and `modules/linkerd`.
- Related submodules in scope: only `modules/linkerd`.
- Repository automation changes: none.
- Current gap: the CRD Helm release has no consumer values input.
- Wrapper preservation: the grouped `linkerd` object remains intact; the new
  optional field mirrors the two existing chart configuration maps.
- Optional mapping: `configs_crds = optional(any, {})`; omission yields `{}`.
- Documentation/test gap: current Linkerd docs and examples do not describe CRD
  chart configuration.
- New-module sourcing and scratch-template comparisons are not applicable
  because this extends an existing wrapper.

## Proposed File Changes

- Update `variables.tf` with optional root `linkerd.configs_crds`.
- Update `main.tf` to forward the value.
- Update `modules/linkerd/variables.tf` with `configs_crds`.
- Update `modules/linkerd/main.tf` to set CRD release values.
- Create `modules/linkerd/tests/configs_crds.tftest.hcl`.
- Update `examples/eks-with-linkerd/1-example.tf`.
- Regenerate/update `modules/linkerd/README.md`.
- Leave providers, versions, outputs, and unrelated modules unchanged.

## Risks and Approvals

- Breaking changes: none expected.
- Interface widening: bounded and explicitly approved by the user.
- Operational risk: enabling `installGatewayAPI` creates cluster-wide CRDs, but
  the module default remains unchanged and consumers must opt in.
- Existing dirty files in the primary checkout are isolated from this worktree.

## Validation

1. Run the targeted native Terraform test and observe it fail before
   implementation.
2. Implement the minimal interface and Helm values wiring.
3. Run the targeted test and confirm it passes.
4. Run `terraform fmt -check -recursive`.
5. Initialize and validate the Linkerd child example with backend disabled.
6. Run pre-commit checks for changed files.
