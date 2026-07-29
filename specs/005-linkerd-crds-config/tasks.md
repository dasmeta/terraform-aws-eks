# Tasks: Linkerd CRD Chart Configuration

**Input**: `specs/005-linkerd-crds-config/spec.md`
**Prerequisites**: `spec.md`, `plan.md`

## Phase 1: Test-First Contract

- [ ] T001 [US1] Add a native Terraform test in
  `modules/linkerd/tests/configs_crds.tftest.hcl` asserting that explicit CRD
  values reach `helm_release.this_crds`.
- [ ] T002 [US1] Run the targeted test and confirm it fails because
  `configs_crds` is not declared.

## Phase 2: Linkerd Child Module

- [ ] T003 [US1] Add optional `configs_crds` input in
  `modules/linkerd/variables.tf`.
- [ ] T004 [US1] Encode `var.configs_crds` into
  `helm_release.this_crds.values` in `modules/linkerd/main.tf`.
- [ ] T005 [US1] Run the targeted test and confirm it passes.

## Phase 3: Root EKS Interface

- [ ] T006 [US1] Add `configs_crds = optional(any, {})` to the root
  `linkerd` object in `variables.tf`.
- [ ] T007 [US1] Forward `var.linkerd.configs_crds` to the child module in
  `main.tf`.
- [ ] T008 [US2] Validate that omitting `configs_crds` remains accepted.

## Phase 4: Documentation

- [ ] T009 [US1] Update `examples/eks-with-linkerd/1-example.tf` with the
  explicit `installGatewayAPI = true` configuration.
- [ ] T010 [US1] Update generated Linkerd input documentation in
  `modules/linkerd/README.md`.

## Phase 5: Verification

- [ ] T011 Run `terraform fmt -check -recursive`.
- [ ] T012 Initialize and validate the Linkerd child example with backend
  disabled.
- [ ] T013 Run pre-commit checks for all changed files.
- [ ] T014 Review the final diff for unrelated or breaking changes.

## Dependencies

- T001-T002 precede implementation.
- T003-T005 complete the child-module behavior.
- T006-T008 expose that behavior through the root wrapper.
- T009-T010 document the implemented interface.
- T011-T014 verify the full change.
