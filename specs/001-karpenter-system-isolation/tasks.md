# Tasks: Karpenter System Isolation

**Input**: Design documents from `/specs/001-karpenter-system-isolation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Feature spec does not require new automated test files; this plan uses example-based validation tasks.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm baseline behavior and collect implementation guardrails before feature edits.

- [X] T001 Review baseline Karpenter and priority-class configuration in `modules/karpenter/main.tf`, `modules/karpenter/variables.tf`, and `modules/priority-class/main.tf`
- [X] T002 [P] Review root integration points in `main.tf`, `variables.tf`, and `locals.tf` for `karpenter` and `priority_class` data flow
- [X] T003 [P] Review reference scenario in `examples/eks-with-karpenter/1-example.tf` and `examples/eks-with-karpenter/0-setup.tf`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared defaults and compatibility-safe plumbing required by all stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Add or normalize Karpenter default replica baseline (>=2) in `variables.tf` and pass-through wiring in `main.tf`
- [X] T005 Add/normalize derived locals for system-node isolation and Karpenter priority binding in `locals.tf`
- [X] T006 Ensure root module passes merged Karpenter configs to module call in `main.tf` without interface breaking changes
- [X] T007 Document compatibility/fallback expectations for missing priority class and override behavior in `README.md`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Protect System Node Capacity (Priority: P1) 🎯 MVP

**Goal**: Ensure non-critical workloads do not land on dedicated system nodes by default.

**Independent Test**: In `examples/eks-with-karpenter`, deploy a non-critical workload without system-node tolerations and verify it is not scheduled on system nodes while critical components remain schedulable.

### Implementation for User Story 1

- [ ] T008 [US1] Update system-node taint/toleration and nodepool isolation defaults in `modules/karpenter/locals.tf`
- [ ] T009 [US1] Apply corresponding chart values merge logic for node pool isolation in `modules/karpenter/main.tf`
- [X] T010 [US1] Update example system-node policy and non-critical workload placement hints in `examples/eks-with-karpenter/1-example.tf`
- [X] T011 [US1] Add usage guidance for system-node isolation in `README.md` and `examples/eks-with-karpenter/README.md`
- [ ] T012 [US1] Execute quickstart isolation verification steps from `specs/001-karpenter-system-isolation/quickstart.md` and capture outcomes in `specs/001-karpenter-system-isolation/quickstart.md`

**Checkpoint**: User Story 1 is functional and independently validated.

---

## Phase 4: User Story 2 - Highest Priority for Karpenter Pods (Priority: P2)

**Goal**: Ensure Karpenter controller pods use the highest predefined priority class.

**Independent Test**: Verify Karpenter pods resolve to the highest predefined priority class in a feature deployment.

### Implementation for User Story 2

- [X] T013 [US2] Add deterministic highest-priority-class binding defaults for Karpenter in `locals.tf` and `variables.tf`
- [X] T014 [US2] Propagate priority class assignment into Karpenter chart values in `modules/karpenter/main.tf`
- [X] T015 [US2] Align priority-class assumptions and fallback behavior in `modules/priority-class/variables.tf` and `README.md`
- [X] T016 [US2] Update example and docs to show highest-priority assignment for Karpenter in `examples/eks-with-karpenter/1-example.tf` and `examples/eks-with-karpenter/README.md`
- [ ] T017 [US2] Execute quickstart priority verification commands and record expected result criteria in `specs/001-karpenter-system-isolation/quickstart.md`

**Checkpoint**: User Stories 1 and 2 both work independently.

---

## Phase 5: User Story 3 - Reliable Multi-Replica Karpenter Baseline (Priority: P3)

**Goal**: Maintain default Karpenter multi-replica resilience and confirm failover behavior.

**Independent Test**: Confirm at least two Karpenter pods are healthy by default and one-pod failure does not remove autoscaling control.

### Implementation for User Story 3

- [X] T018 [US3] Ensure default replica setting and override semantics remain consistent in `variables.tf`, `locals.tf`, and `main.tf`
- [X] T019 [US3] Validate module-level Karpenter controller replica behavior in `modules/karpenter/main.tf` and adjust merge precedence if needed
- [ ] T020 [US3] Update resilience expectations and operator guidance in `README.md` and `specs/001-karpenter-system-isolation/contracts/karpenter-system-scheduling-contract.md`
- [ ] T021 [US3] Execute quickstart failover verification steps and record validation notes in `specs/001-karpenter-system-isolation/quickstart.md`

**Checkpoint**: All user stories are independently functional and validated.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency, validation, and release-readiness checks.

- [ ] T022 [P] Run formatting and validation for touched Terraform files (`terraform fmt -recursive`, `terraform validate` in relevant example/module roots)
- [ ] T023 [P] Reconcile feature docs (`spec.md`, `plan.md`, `tasks.md`, `quickstart.md`) with final behavior in `specs/001-karpenter-system-isolation/`
- [ ] T024 Confirm no interface widening or breaking change slipped in by reviewing `variables.tf` and module input contracts in `main.tf`
- [ ] T025 Run end-to-end quickstart from `specs/001-karpenter-system-isolation/quickstart.md` and finalize acceptance evidence notes in that file

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: Depend on Foundational completion
- **Polish (Phase 6)**: Depends on all selected user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational, no dependency on other stories
- **User Story 2 (P2)**: Starts after Foundational; should remain independently testable
- **User Story 3 (P3)**: Starts after Foundational; depends conceptually on stable US1 isolation behavior

### Within Each User Story

- Implementation defaults first
- Example and documentation updates second
- Story-specific validation last

### Parallel Opportunities

- `T002` and `T003` can run in parallel during setup
- `T022` and `T023` can run in parallel during polish
- If multiple engineers are available, US2 and US3 may proceed in parallel after US1 baseline is stable

---

## Parallel Example: User Story 2

```bash
# Parallel documentation and behavior alignment for US2:
Task: "T015 Align priority-class assumptions in modules/priority-class/variables.tf and README.md"
Task: "T016 Update example/docs for Karpenter highest-priority in examples/eks-with-karpenter/1-example.tf and examples/eks-with-karpenter/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2
2. Deliver Phase 3 (US1) isolation behavior
3. Validate isolation independently before moving on

### Incremental Delivery

1. Deliver US1 isolation safety baseline
2. Add US2 highest-priority binding
3. Add US3 replica resilience verification
4. Finish cross-cutting polish and validation

### Parallel Team Strategy

1. One engineer completes Setup + Foundational
2. One engineer focuses on US1 implementation and verification
3. Additional engineers pick up US2/US3 once foundational defaults are merged

---

## Notes

- All tasks follow required checklist format with IDs and file paths.
- Story labels are applied only to user-story tasks.
- Validation steps are explicitly captured to satisfy spec success criteria.
