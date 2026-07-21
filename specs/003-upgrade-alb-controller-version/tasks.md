# Tasks: Upgrade AWS Load Balancer Controller Chart Version

**Input**: Design documents from `/specs/003-upgrade-alb-controller-version/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/module-interface.md`, `quickstart.md`

**Tests**: Verification is `terraform validate` for the module/example plus an IAM-policy equivalence check. Full controller runtime behavior requires a real EKS cluster and is exercised by downstream consumers.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm scope and lock the version baseline.

- [x] T001 Capture the current default (`chart.version = 3.3.0`) as the implementation baseline in `specs/003-upgrade-alb-controller-version/quickstart.md`
- [x] T002 Confirm latest stable chart version and its controller `appVersion` from the `eks-charts` index

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify the IAM policy contract before bumping the chart.

**⚠️ CRITICAL**: The IAM parity check must pass before the version bump is considered safe.

- [x] T003 Fetch the upstream controller IAM policy for the previous and target versions and diff them (result: identical)
- [x] T004 Diff the vendored `modules/aws-load-balancer-controller/iam-policy.json` against the upstream target policy (result: equivalent -> no policy change needed)

**Milestone**: IAM parity confirmed; the bump is safe.

---

## Phase 3: User Story 1 - Consume the up-to-date controller chart by default (Priority: P1) 🎯 MVP

**Goal**: Move the default chart version to `3.4.2` without breaking default consumer flow.

**Independent Test**: Plan `examples/basic` with defaults and confirm the chart resolves to `3.4.2`.

### Implementation for User Story 1

- [x] T005 [US1] Update `chart.version` default `3.3.0` -> `3.4.2` in `modules/aws-load-balancer-controller/variables.tf`
- [x] T006 [US1] Update the generated input table default in `modules/aws-load-balancer-controller/README.md`
- [x] T007 [US1] Update the pinned version in `modules/aws-load-balancer-controller/examples/basic/1-example.tf`

**Milestone**: US1 default updated and independently verifiable.

---

## Phase 4: User Story 2 - IAM policy stays correct for the new controller version (Priority: P2)

**Goal**: Ensure the vendored IAM policy matches the target controller version.

**Independent Test**: Compare vendored policy to the upstream policy for the target version.

### Implementation for User Story 2

- [x] T008 [US2] Confirm no IAM permission delta between previous and target controller versions (verified in Phase 2)
- [x] T009 [US2] Leave `iam-policy.json` unchanged (equivalent to target); document the parity result in `research.md`

**Milestone**: IAM policy contract verified for the target version.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final consistency and validation.

- [x] T010 [P] Run `terraform fmt -recursive` on `modules/aws-load-balancer-controller`
- [x] T011 Run `terraform validate` on `modules/aws-load-balancer-controller/examples/basic`
- [x] T012 Confirm README and example reflect the `3.4.2` default

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Starts immediately.
- **Phase 2 (Foundational / IAM parity)**: Depends on Phase 1; blocks the version bump.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Verified within Phase 2; documented here.
- **Phase 5 (Polish)**: Depends on US1/US2.

### Parallel Opportunities

- T006 and T007 can run in parallel after T005.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2 (IAM parity).
2. Deliver Phase 3 (US1) version bump end-to-end.
3. Validate US1 independently as MVP.

### Incremental Delivery

1. Foundation (Phases 1-2): confirm IAM parity.
2. US1: chart version default bump.
3. US2: document IAM policy parity result.
4. Polish and validation.
