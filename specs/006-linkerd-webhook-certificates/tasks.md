# Tasks: Long-Lived Linkerd Admission Webhook Certificates

**Input**: `specs/006-linkerd-webhook-certificates/spec.md`
**Prerequisites**: `spec.md`, `plan.md`

All tasks are marked complete: this package was authored after the
implementation, as recorded in the Process Note in `plan.md`.

## Phase 1: Research

- [X] T001 [US1] Confirm the chart self-generates webhook certificates with a
  1-year validity when none are supplied, and that all three webhooks default to
  `failurePolicy: Ignore`.
- [X] T002 [US1] Identify the exact chart value keys for the three webhooks
  (`proxyInjector`, `profileValidator`, `policyValidator`) and confirm
  `spValidator` carries only resource configuration, not certificate values.
- [X] T003 [US1] Confirm the Kubernetes Service names each webhook uses are
  hardcoded by the chart rather than derived from the Helm release name.

## Phase 2: Certificate Submodule

- [X] T004 [US1] Create
  `modules/linkerd/modules/webhook-certificates-and-keys/` with `versions.tf`,
  `variables.tf`, `main.tf`, and `outputs.tf`, mirroring the file set and
  constraints of `identity-certificates-and-keys`.
- [X] T005 [US1] Generate a key and self-signed certificate per webhook with
  `validity_period_hours` defaulting to `187600`.
- [X] T006 [US1] Set each certificate's subject and subject alternative names to
  cover the bare, namespaced, `.svc`, and `.svc.cluster.local` forms of its
  Service name.
- [X] T007 [US1] Expose `crtPEM`/`keyPEM`/`caBundle` per webhook from a single
  output marked sensitive, with `caBundle` set to the certificate itself.

## Phase 3: Wiring

- [X] T008 [US1] Invoke the new submodule from `modules/linkerd/configs.tf`,
  passing `var.namespace`.
- [X] T009 [US1] Add the three webhook value maps to the control-plane chart
  defaults.
- [X] T010 [US3] Move the chart default maps into `modules/linkerd/locals.tf`.
- [X] T011 [US3] Replace the Terraform-side deep merge by passing module defaults
  and consumer configs as two `helm_release` `values[]` entries.

## Phase 4: Key Encoding Fix

- [X] T012 [US2] Reproduce the policy controller failing to load the supplied key
  and confirm it is the only crashing container in the pod.
- [X] T013 [US2] Switch `keyPEM` to the PKCS#8 encoded key for all three
  webhooks.
- [X] T014 [US2] Record the reason inline in `outputs.tf` so the choice is not
  reverted as a cleanup.

## Phase 5: Version Constraints

- [X] T015 Declare the Helm provider in object form with an explicit source and a
  `~> 2.0` constraint in `modules/linkerd/versions.tf`.
- [X] T016 Set `required_version = "~> 1.3"` across the module and both nested
  submodules.

## Phase 6: Tests and Documentation

- [X] T017 [US1] Add `modules/linkerd/tests/webhook_certificates.tftest.hcl`
  asserting the generated certificates reach the control-plane release and that
  each `caBundle` matches its `crtPEM`.
- [X] T018 [US3] Extend the test to assert defaults and consumer configs are
  passed as two correctly ordered `values[]` entries.
- [X] T019 Regenerate affected `README.md` files through the repository's
  `terraform_docs` pre-commit hook.

## Phase 7: Verification

- [X] T020 Run `terraform fmt -check -recursive`.
- [X] T021 Run `terraform validate` for the module and both submodules.
- [X] T022 Run the native test suite.
- [X] T023 Verify Helm's merge semantics against a scratch chart, covering nested
  map merging and list replacement.
- [X] T024 Inspect generated certificates out-of-band for validity period,
  subject, subject alternative names, `caBundle` equality, and key pair match.
- [X] T025 Apply against a live cluster and confirm the control-plane pod reaches
  full readiness with no restarts.
- [X] T026 Run pre-commit checks for all changed files and review the final diff
  for unrelated or breaking changes.

## Follow-Up (Out of Scope)

- [ ] T027 Move webhook and identity certificate management to cert-manager via
  the chart's `externalSecret` and `injectCaFrom` values, to keep private keys out
  of Terraform state and plan output and to gain real rotation. Tracked as a
  separate issue.

## Dependencies

- T001-T003 establish the chart contract that everything else relies on.
- T004-T007 build the certificate source.
- T008-T011 wire it into the chart values.
- T012-T014 depend on T025 having surfaced the failure; the fix could not have
  been derived from static inspection alone.
- T015-T016 are independent of the certificate work and share only the files.
- T017-T019 document and lock in the implemented behavior.
- T020-T026 verify the full change.
