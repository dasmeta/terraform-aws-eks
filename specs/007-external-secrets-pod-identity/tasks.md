# Tasks: External Secrets on EKS Pod Identity with Role Chaining

**Input**: `specs/007-external-secrets-pod-identity/spec.md`
**Prerequisites**: `spec.md`, `plan.md`

All tasks are marked complete: this package was authored after the implementation, as recorded
in the Process Note in `plan.md`.

## Phase 1: Controller Identity

- [X] T001 [US1] Replace the `terraform-module/release/helm` wrapper with a direct
  `helm_release`, with layered values entries merged by Helm.
- [X] T002 [US1] Add the controller base IAM role, trusting `pods.eks.amazonaws.com` for Pod
  Identity or the OIDC provider for IRSA depending on the selected attachment method.
- [X] T003 [US1] Grant the base role only `sts:AssumeRole` on the per-store role name prefix;
  grant no Secrets Manager actions.
- [X] T004 [US1] Create the `aws_eks_pod_identity_association` for the controller service
  account.
- [X] T005 [US1] Add chart-source and image-override inputs so a private repository or archive
  can be used.

## Phase 2: Credential Delivery

- [X] T006 [US2] Order the association before the Helm release so a fresh install has
  credentials available when the pods first start.
- [X] T007 [US2] Add `eks-pod-identity-agent` to `var.default_addons` so associations actually
  deliver credentials, without conditional enablement logic.
- [X] T008 [US2] Reproduce the stale-credential failure on a live upgrade and identify that Pod
  Identity injects credentials at pod admission time.
- [X] T009 [US2] Annotate all three pod templates with the controller role ARN so an identity
  change rolls the deployments.
- [X] T010 [US2] Verify by rendering the chart that the annotation reaches the controller,
  webhook and cert-controller pod templates and does not drop the image overrides.

## Phase 3: Upgrade Safety

- [X] T011 [US3] Add `moved.tf` re-pointing the release from
  `module.release.helm_release.this[0]` to `helm_release.this`.
- [X] T012 [US3] Confirm the old address against the previous released module source.

## Phase 4: Consumer Interface

- [X] T013 [US4] Wire the grouped `external_secrets` variable through the root module; it was
  previously declared but never read.
- [X] T014 [US4] Nest IAM fields under `iam` to match `alb_load_balancer_controller`, with
  inline per-field comments.
- [X] T015 [US4] Retain the previously released top-level variables as deprecated inputs that
  take precedence when explicitly set, so the staged upgrade runbook keeps working.
- [X] T016 [US4] Add the `external_secrets` root output exposing the controller role ARN and
  store role name prefix; mark the stale `external_secret_deployment` output deprecated.
- [X] T017 [US4] Update the example to consume those outputs.

## Phase 5: Correctness Fixes Found During Review

- [X] T018 Fix the submodule `region` input, whose `""` default did not match its `null`
  data-source guard and made a standalone call fail in `coalesce`.

## Phase 6: Documentation

- [X] T019 Add the `>= 2.28.0` upgrade guide entry covering the two-repository ordering, the
  destroyed static-credential resources, the pod restart behaviour and its manual fallback.
- [X] T020 Add validation steps that force a live refetch, since a broken store keeps serving
  its last synced Secret and looks healthy otherwise.
- [X] T021 Document the Pod Identity restart behaviour in the submodule's own header.
- [X] T022 Regenerate affected `README.md` files through the `terraform_docs` hook.

## Phase 7: Verification

- [X] T023 Run `terraform fmt -check -recursive` across both repositories.
- [X] T024 Run `terraform validate` for the root, submodule, store module and example.
- [X] T025 Run `tflint`, `tfsec` and `checkov` against the changed modules.
- [X] T026 Render the consuming chart and confirm the store reference, kind, apiVersion and
  remote key line up with what the store module creates.
- [X] T027 Run the pre-commit hooks over all changed files.
- [X] T028 Apply against a live cluster and confirm secrets sync after the controller pods pick
  up the new identity.

## Follow-Up (Out of Scope)

- [ ] T029 Replace hardcoded `aws` partition ARNs with `data.aws_partition` across the
  repository; currently no module uses it, so changing only this one would diverge.
- [ ] T030 Resync the root `README.md` provider rows, which are committed as resolved versions
  and drift on every docs regeneration.

## Dependencies

- T001-T005 establish the identity and release.
- T006-T010 make credentials actually reach the pods; T009 depends on T008 having surfaced the
  failure, which static analysis could not.
- T011-T012 protect the upgrade path.
- T013-T017 expose the identity to consumers; the store module change in the other repository
  depends on T016.
- T019-T022 document the result.
- T023-T028 verify the whole change.
