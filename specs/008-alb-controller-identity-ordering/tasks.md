# Tasks: AWS Load Balancer Controller Identity Ordering

**Input**: `specs/008-alb-controller-identity-ordering/spec.md`
**Prerequisites**: `spec.md`, `plan.md`

All tasks are marked complete: this package was authored after the implementation, as recorded
in the Process Note in `plan.md`.

## Phase 1: Diagnosis

- [X] T001 Reproduce the report: fresh install, Ingress reports `AccessDenied` on ELB describe
  calls while the policy is visibly attached to the role, and a controller pod restart clears it.
- [X] T002 Establish that both credential mechanisms bind at pod start - IRSA through the
  projected service account token at pod creation, Pod Identity through environment variables
  injected at admission - so neither recovers a pod that started without them.
- [X] T003 Identify the missing graph edge: `helm_release` depended only on `aws_iam_role` via the
  role ARN in the service account annotation, leaving `aws_iam_role_policy_attachment` to be
  created in parallel with the chart install.
- [X] T004 Identify the inverted dependency: `aws_eks_pod_identity_association` declared
  `depends_on = [helm_release...]`, guaranteeing credential-less pods in Pod Identity mode.
- [X] T005 Explain why the failure looks permanent: controller-runtime backs a failing Ingress
  reconcile off toward its ceiling, so the stale condition long outlives the IAM problem.
- [X] T006 Compare against `modules/external-secrets`, which already orders its association before
  its release and annotates its pod templates, and adopt that pattern rather than a new one.

## Phase 2: Ordering

- [X] T007 [US1] Add explicit `depends_on` from `helm_release` to the policy attachment and the
  Pod Identity association.
- [X] T008 [US2] Remove the association's `depends_on` on the Helm release and record in a comment
  why the association can safely be created before the namespace and service account exist.
- [X] T009 [US1] Add `time_sleep.iam_propagation` between the identity wiring and the release, to
  absorb IAM/STS eventual consistency.
- [X] T010 [US1] Trigger the wait on the identity values so it runs on identity change only, not
  on every apply.
- [X] T011 [US1] Gate the wait on `propagation_delay != "0s"` so it can be opted out of entirely.

## Phase 3: Credential Delivery to Running Pods

- [X] T012 [US3] Derive `identity_annotation` from the role ARN, the policy attachment id and the
  attachment method, reusing the `checksum/aws-identity` key already used by external-secrets.
- [X] T013 [US3] Add it to the chart values as `podAnnotations`, layered so consumer-supplied
  annotations in `configs` still merge.
- [X] T014 [US3] Confirm by rendering the pinned chart that the annotation reaches the
  controller's pod template.

## Phase 4: Consumer Interface

- [X] T015 Add `iam.propagation_delay` to the submodule with a default and an inline comment.
- [X] T016 Add a validation rejecting values that are not Go duration strings, including compound
  forms such as `1m30s`.
- [X] T017 Mirror the field into the root `alb_load_balancer_controller.iam` object so it is
  reachable from the wrapper.
- [X] T018 Declare the `hashicorp/time` provider in the submodule with a pessimistic constraint.

## Phase 5: Tuning

- [X] T019 Reduce the default wait from `30s` to `15s` after the reporter confirmed the fix works,
  on the basis that ordering is what removes the race and the chart install, image pull and leader
  election already stand between the wait and the controller's first AWS call.

## Phase 6: Documentation

- [X] T020 Document credential delivery, the ordering, the wait and the pod-template stamp in the
  submodule header, so the reasoning survives the next reader who sees a redundant-looking
  `depends_on`.
- [X] T021 Add the `>= 2.30.0` upgrade guide entry covering the one-time controller rollout, the
  new provider requirement, and the opt-out.
- [X] T022 Regenerate affected `README.md` files through the `terraform_docs` hook, without
  leaving a submodule lock file behind that would pin resolved provider versions into the docs.

## Phase 7: Verification

- [X] T023 Run the `terraform_fmt` pre-commit hook.
- [X] T024 Run `terraform validate` for the submodule and the root module.
- [X] T025 Plan the submodule in IRSA mode, Pod Identity mode, and with `propagation_delay = "0s"`,
  confirming the expected resource counts in each.
- [X] T026 Inspect `terraform graph` and confirm the release is ordered after the wait, and the
  wait after both the policy attachment and the association.
- [X] T027 Confirm an invalid duration is rejected by variable validation.
- [X] T028 Confirm the default renders as `create_duration = "15s"` in a fresh plan.
- [X] T029 Confirm on a live cluster that a fresh install attaches an Ingress to an ALB without a
  manual controller restart (performed by the reporter).

## Follow-Up (Out of Scope)

- [ ] T030 Audit the remaining submodules that pair a `helm_release` with IAM resources for the
  same missing edge; `external-secrets` and this module are fixed, the others are unreviewed.
- [ ] T031 Consider a repository-wide convention, documented once, for ordering workload identity
  ahead of the release that consumes it, so this is not rediscovered per module.

## Dependencies

- T001-T006 establish the cause; T007-T011 depend on T003 and T004 having identified the two
  specific graph defects.
- T012-T014 cover what ordering alone cannot: pods that are already running.
- T015-T018 expose and support the new behaviour.
- T019 depends on T029, the live confirmation, having succeeded at the original value.
- T020-T022 document the result.
- T023-T029 verify the whole change.
