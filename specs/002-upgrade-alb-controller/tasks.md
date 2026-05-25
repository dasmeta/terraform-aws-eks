# Tasks: Upgrade ALB Controller

**Input**: Design documents from `/specs/002-upgrade-alb-controller/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Validation in this feature is example-driven. Include Terraform formatting, validation, docs sync, and dedicated example checks as execution tasks.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the feature workspace and inspect existing module/example assets that will be changed

- [X] T001 Capture the current ALB controller module and root wrapper state in `modules/aws-load-balancer-controller/` and `alb-ingress-controller.tf`
- [X] T002 Review existing example patterns in `examples/extra-tooling-disabled/`, `examples/basic/`, and `examples/eks-with-istio-gateway-api/` for reuse in `examples/eks-with-alb-controller/`
- [X] T003 Review current module docs surfaces in `modules/aws-load-balancer-controller/README.md` and root `README.md` before implementation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core module structure and compatibility groundwork that MUST complete before user story work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Refresh `modules/aws-load-balancer-controller/iam-policy.json` from the upstream `v3.3.0` policy source and note any permission drift relevant to the module
- [X] T005 Remove dead ALB log implementation files from `modules/aws-load-balancer-controller/logs-to-cloudwatch.tf`, `modules/aws-load-balancer-controller/s3-bucket.tf`, and `modules/aws-load-balancer-controller/terraform-aws-alb-cloudwatch-logs-json/`
- [X] T006 [P] Define the child-module compatibility-safe variable surface in `modules/aws-load-balancer-controller/variables.tf` for release source, image override, and identity modes
- [X] T007 [P] Define the root-wrapper compatibility-safe variable surface in `variables.tf` for new `alb_load_balancer_controller` optional fields while preserving existing callers
- [X] T008 Align root-to-child wiring in `alb-ingress-controller.tf` with the planned compatibility behavior, including deprecated no-op ALB log input handling

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Upgrade Controller Safely (Priority: P1) 🎯 MVP

**Goal**: Upgrade the controller to the new upstream baseline without breaking existing main-module usage

**Independent Test**: Run Terraform validation against the repository after applying the upgraded child module and root wrapper changes, confirming existing ALB-controller callers do not require new mandatory inputs.

### Implementation for User Story 1

- [X] T009 [US1] Upgrade the Helm release implementation in `modules/aws-load-balancer-controller/main.tf` to the `3.3.0` baseline while preserving default install behavior
- [X] T010 [US1] Update IAM role and policy attachment logic in `modules/aws-load-balancer-controller/iam.tf` to consume the refreshed policy artifact cleanly
- [X] T011 [US1] Reconcile provider/version expectations for the upgraded module in `modules/aws-load-balancer-controller/versions.tf`
- [X] T012 [US1] Preserve backward-compatible root wrapper defaults and mappings in `alb-ingress-controller.tf` and `variables.tf`
- [X] T013 [US1] Update module usage documentation in `modules/aws-load-balancer-controller/README.md` for the upgraded baseline and backward-compatible behavior

**Checkpoint**: User Story 1 should be functional and testable with existing root-module usage

---

## Phase 4: User Story 2 - Choose Runtime Integration Method (Priority: P2)

**Goal**: Support service-account annotation, built-in Pod Identity association, and externally managed association modes with clear validation

**Independent Test**: Validate the configuration surface so the module supports each approved identity state and rejects simultaneous built-in service-account annotation plus built-in Pod Identity attachment.

### Implementation for User Story 2

- [X] T014 [US2] Implement identity-mode inputs and validation rules in `modules/aws-load-balancer-controller/variables.tf`
- [X] T015 [US2] Implement IAM trust and attachment behavior for service-account annotation, Pod Identity association, and external-association mode in `modules/aws-load-balancer-controller/iam.tf`
- [X] T016 [US2] Update Helm values rendering in `modules/aws-load-balancer-controller/main.tf` so service-account annotations are only applied for the legacy attachment mode
- [X] T017 [US2] Expose and document root-wrapper identity controls in `variables.tf`, `alb-ingress-controller.tf`, and `README.md`
- [X] T018 [US2] Document the three supported identity states and operator checks in `modules/aws-load-balancer-controller/README.md`

**Checkpoint**: User Story 2 should be independently testable through configuration-state inspection and validation

---

## Phase 5: User Story 3 - Reuse Module Across Distribution Sources (Priority: P3)

**Goal**: Support default, custom-repository, and direct-package chart sourcing plus controller image overrides

**Independent Test**: Render or validate the module with default source behavior, custom repository/chart values, and direct packaged-chart input while verifying image override inputs map correctly and direct-package input ignores repository.

### Implementation for User Story 3

- [X] T019 [US3] Implement chart source selection and direct-package precedence in `modules/aws-load-balancer-controller/main.tf`
- [X] T020 [US3] Implement controller image repository and tag override support in `modules/aws-load-balancer-controller/main.tf`
- [X] T021 [US3] Add child-module input documentation for source and image controls in `modules/aws-load-balancer-controller/variables.tf` and `modules/aws-load-balancer-controller/README.md`
- [X] T022 [US3] Extend root-wrapper ALB controller options in `variables.tf` and `alb-ingress-controller.tf` with the narrow optional source/image controls
- [X] T023 [US3] Update operator guidance in `modules/aws-load-balancer-controller/README.md` and root `README.md` to document source precedence, ignored `repository` behavior, and image override usage

**Checkpoint**: User Story 3 should be independently testable by validating each source-selection path and image override mapping

---

## Phase 6: User Story 4 - Validate With a Minimal Example (Priority: P4)

**Goal**: Add a minimal, self-contained example that demonstrates controller-managed ingress behavior using the default annotation attachment path

**Independent Test**: Apply the dedicated example and verify the controller deploys with the default annotation path, the `http-echo` workload is installed, and the ingress-facing behavior can be demonstrated with optional extras disabled.

### Implementation for User Story 4

- [X] T024 [P] [US4] Create example provider and environment setup in `examples/eks-with-alb-controller/0-setup.tf`
- [X] T025 [P] [US4] Create the example cluster and module configuration in `examples/eks-with-alb-controller/1-example.tf`
- [X] T026 [P] [US4] Add the sample workload and ingress manifest in `examples/eks-with-alb-controller/http-echo-alb-controller.yaml`
- [X] T027 [US4] Write example usage and validation guidance in `examples/eks-with-alb-controller/README.md`
- [X] T028 [US4] Ensure the example keeps unrelated optional components disabled and uses service-account annotation by default in `examples/eks-with-alb-controller/1-example.tf`

**Checkpoint**: User Story 4 should be independently testable through the new dedicated example

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Finish documentation, generated docs, and verification across all stories

- [X] T029 [P] Sync Terraform-generated documentation in `modules/aws-load-balancer-controller/README.md`, `examples/eks-with-alb-controller/README.md`, and root `README.md`
- [X] T030 Add the architecture sketch and future upgrade/maintenance procedure to `modules/aws-load-balancer-controller/README.md`
- [X] T031 Run repository formatting and validation for the changed Terraform files from the repository root
- [X] T032 Run the dedicated example validation flow described in `specs/002-upgrade-alb-controller/quickstart.md` and record any environment limitations in the implementation summary

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational - defines the upgraded baseline and compatibility behavior
- **User Story 2 (P2)**: Starts after Foundational - builds on the upgraded baseline from US1
- **User Story 3 (P3)**: Starts after Foundational - builds on the upgraded baseline from US1
- **User Story 4 (P4)**: Starts after US1 and should incorporate decisions from US2 and US3 where documented, but remains independently testable as a minimal example

### Within Each User Story

- Module variable and validation changes before dependent wiring updates
- IAM and Helm behavior before docs that describe the final supported behavior
- Example setup before example documentation and validation
- Verification after implementation and docs sync

### Parallel Opportunities

- T006 and T007 can run in parallel because they shape child and root variable surfaces in different files
- T024, T025, and T026 can run in parallel because they create separate example files
- T029 can run in parallel with verification preparation once implementation is complete

---

## Parallel Example: User Story 4

```bash
# Launch independent example file creation tasks together:
Task: "Create example provider and environment setup in examples/eks-with-alb-controller/0-setup.tf"
Task: "Create the example cluster and module configuration in examples/eks-with-alb-controller/1-example.tf"
Task: "Add the sample workload and ingress manifest in examples/eks-with-alb-controller/http-echo-alb-controller.yaml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Confirm the upgraded baseline is backward-compatible

### Incremental Delivery

1. Deliver the upgraded baseline first (US1)
2. Add identity-mode support (US2)
3. Add source/image flexibility (US3)
4. Add the minimal validation example (US4)
5. Finish docs sync and verification

### Parallel Team Strategy

With multiple developers:

1. Complete Setup + Foundational together
2. After Foundational:
   - Developer A: US1 baseline upgrade
   - Developer B: US2 identity mode support
   - Developer C: US3 source/image flexibility
3. Once module behavior stabilizes, example work (US4) can proceed with docs and validation alignment

---

## Notes

- [P] tasks target separate files and should avoid merge conflicts when executed carefully
- User story phases are intended to remain independently understandable and testable
- Verification is example-driven rather than unit-test-driven for this feature
- Deprecated ALB log inputs are compatibility-sensitive; do not remove accepted caller surface without explicit approval
