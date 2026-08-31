# Tasks: Karpenter Stability Baseline

**Input**: Design documents from `/specs/009-karpenter-stability-baseline/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included and mandatory. The determinism defect (SC-003) must be demonstrated failing before it is fixed, matching the baseline-first rule applied across DMVP-10430.

**Organization**: Grouped by user story. US1 and US2 are both P1.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

- [X] T001 Create `tests/` at repository root for native `terraform test` files, placed flat because `terraform test` does not discover nested per-case directories
- [X] T002 Add `tests/karpenter_defaults.tftest.hcl` with `command = plan` runs, using variable overrides only so no AWS credentials are required

---

## Phase 2: Foundational — baseline (BLOCKING)

- [X] T003 Record the current rendered Karpenter values as a baseline in `specs/009-karpenter-stability-baseline/baseline-results.md`: controller resources, priority class, `amiSelectorTerms` shape, node pool disruption block, and chart versions
- [X] T004 Demonstrate the determinism defect: show that `modules/karpenter/data.tf` resolves `aws_instances...ids[0]` and that the selected AMI is a function of running infrastructure rather than configuration. Record the mechanism in `baseline-results.md`, since reproducing the flip requires node turnover and belongs to the live tier
- [X] T005 Confirm the pinned upstream policy lacks `ec2:DescribeInstanceStatus` by inspecting the vendored `policy.tf`, and record it

**Checkpoint**: Current behaviour recorded. Module edits may begin.

---

## Phase 3: User Story 1 — Controller stays up (P1)

**Goal**: The controller is neither OOMKilled, throttled, nor preempted.

**Independent Test**: Rendered chart values carry the validated requests, a memory limit, no CPU limit, and `system-cluster-critical`.

- [X] T006 [US1] Add the `controller_resources` grouped input to `modules/karpenter/variables.tf` with optional attributes and an inline comment on every field, defaulting to requests `250m`/`512Mi` and a `1Gi` memory limit with no CPU limit
- [X] T007 [US1] Replace the hard-coded `controller.resources` block in `modules/karpenter/main.tf` with the new input, ensuring an operator-supplied value fully replaces the default rather than merging with it
- [X] T008 [US1] Change the Karpenter priority default in root `locals.tf` from the priority-class-derived value to `system-cluster-critical`, keeping `var.karpenter.configs.priorityClassName` as the override
- [X] T009 [US1] Add the replica/subnet precondition to `modules/karpenter/main.tf`: fail the plan when more than one replica is requested with fewer than two subnets, naming the requirement in the error
- [X] T010 [US1] Add assertions to `tests/karpenter_defaults.tftest.hcl` covering the resource shape, the absence of a CPU limit, and the priority class

---

## Phase 4: User Story 2 — Capacity changes happen on purpose (P1)

**Goal**: Image selection is a pure function of configuration.

**Independent Test**: Repeated plans over unchanged configuration select an identical image.

- [X] T011 [US2] Add the `ami_alias` input to `modules/karpenter/variables.tf`, defaulting to a family derived from the declared node group AMI type with version `latest`, and document pinning
- [X] T012 [US2] Replace the instance-derived `amiSelectorTerms` in `modules/karpenter/locals.tf` with the `alias` form for the default node class
- [X] T013 [US2] Delete the now-unused `aws_instances` and `aws_instance` data sources from `modules/karpenter/data.tf`, leaving no dead data source behind
- [X] T014 [US2] Pass the alias family derived from `node_groups_default.ami_type` through root `main.tf` to the submodule, keeping the submodule usable standalone with an `al2023` default
- [X] T015 [US2] Add `ec2:DescribeInstanceStatus` to the `iam_policy_statements` block in `modules/karpenter/main.tf`, with a comment stating which Karpenter version requires it and why. Do not add `ec2:DescribePlacementGroups`, which this module does not need
- [X] T016 [US2] Add assertions covering image-selection determinism and the presence of the IAM statement

---

## Phase 5: User Story 3 — Voluntary disruption confined to safe hours (P2)

- [X] T017 [US3] Add the `disruption_windows` grouped input to `modules/karpenter/variables.tf` with inline comments, defaulting to 06:00-18:00 UTC Monday to Friday blocking `Drifted` and `Underutilized`
- [X] T018 [US3] Render window entries into every node pool's `disruption.budgets` in `modules/karpenter/locals.tf`, preserving the existing percentage budget alongside them
- [X] T019 [US3] Change the default consolidation policy to `Balanced` and raise `consolidateAfter` from `3m` to `15m` in `modules/karpenter/variables.tf`
- [X] T020 [US3] Add the `termination_grace_period` input defaulting to `24h` and render it into each node pool template spec
- [X] T021 [US3] Add assertions covering rendered budgets, the consolidation policy, and the grace period

---

## Phase 6: User Story 4 — Protected capacity (P2)

- [X] T022 [US4] Add the `protected_node_pool` grouped input to `modules/karpenter/variables.tf`, disabled by default, with inline comments on every field
- [X] T023 [US4] Render the protected pool in `modules/karpenter/locals.tf` when enabled: on-demand only, tainted, `WhenEmpty` consolidation, excluded from the disruption windows
- [X] T024 [US4] Add an assertion that nothing is rendered when the pool is disabled, and that the taint and capacity type are correct when enabled

---

## Phase 7: User Story 5 — Reduced exposure to reclamation (P3)

- [X] T025 [US5] Widen the default instance requirements in `modules/karpenter/variables.tf` to CPU 2-32 and memory 2-128 GiB, keeping generation above 2 and `amd64`, with comments explaining each bound
- [X] T026 [US5] Add an assertion that the rendered requirements match the widened bounds

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T027 Bump the Karpenter chart default from `1.9.0` to `1.14.1` in `modules/karpenter/variables.tf`, covering both the definitions and main charts
- [X] T028 Bump the `karpenter-nodes` chart default from `0.1.0` to `0.1.2`
- [X] T029 [P] Update `examples/eks-with-karpenter/1-example.tf` to demonstrate the new defaults, removing configuration now redundant
- [X] T030 [P] Update `examples/eks-with-karpenter-and-external-secret/1-example.tf` to demonstrate the protected node pool, and reconsider its `replicas = 1` setting against the new precondition
- [X] T031 Run `terraform fmt -recursive` and `terraform validate` across the module and both examples
- [X] T032 Run `terraform test` and confirm every assertion passes
- [X] T033 [P] Regenerate `modules/karpenter/README.md` inputs documentation for the new variables
- [X] T034 Add the upgrade guide entry to the root `main.tf` header docs following the existing convention: every changed default, the one-time paced node roll, the UTC and daylight-saving caveat on disruption windows, the definitions-chart upgrade steps, and the two deliberate non-changes with their reasoning
- [X] T035 Update `specs/009-karpenter-stability-baseline/baseline-results.md` with the after-state so the before/after contrast is recorded evidence

---

## Dependencies

```text
Phase 1 (T001-T002)
   └─> Phase 2 (T003-T005)   BLOCKING: record current behaviour first
          ├─> Phase 3 US1 (T006-T010)
          ├─> Phase 4 US2 (T011-T016)
          ├─> Phase 5 US3 (T017-T021)   depends on locals from Phase 4
          ├─> Phase 6 US4 (T022-T024)   depends on Phase 5 windows
          └─> Phase 7 US5 (T025-T026)
                 └─> Phase 8 (T027-T035)
```

- T013 depends on T012: the data sources cannot be removed until nothing reads them.
- T023 depends on T018: the protected pool must be excluded from the windows, which must exist first.
- T034 depends on every behavioural change being final.

## Parallel Execution Opportunities

- Phase 7 is independent of Phases 5 and 6 and can proceed alongside them.
- T029, T030 and T033 touch different files.

## Implementation Strategy

**MVP scope**: Phases 1 to 4 (T001-T016). That is a controller which stays running under load, is not preempted, and never triggers a node roll by accident — the two P1 stories and the direct causes of the originating incident.

**Incremental delivery**: Phases 5 to 7 reduce how often harm occurs. Phase 8 is required before release: the chart upgrade and the upgrade guide are what make the change safe to adopt.
