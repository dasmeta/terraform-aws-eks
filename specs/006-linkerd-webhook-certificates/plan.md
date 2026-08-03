# Implementation Plan: Long-Lived Linkerd Admission Webhook Certificates

**Branch**: `fix-linkerd-webhook-cert-expiry` | **Date**: 2026-07-31 |
**Spec**: `specs/006-linkerd-webhook-certificates/spec.md`

## Summary

Add a `webhook-certificates-and-keys` submodule that generates self-signed
21-year certificates for the three `linkerd-control-plane` admission webhooks,
and forward them into the control-plane Helm release. Mirror the structure of the
existing `identity-certificates-and-keys` submodule. Preserve the consumer
interface and the defaults/override precedence contract exactly.

## Technical Context

**Language/Version**: Terraform `~> 1.3`
**Primary Dependencies**: HashiCorp Helm provider `~> 2.0`, TLS provider `~> 4.0`,
Linkerd Helm charts
**Storage**: Terraform state holds the generated private keys
**Testing**: Terraform native tests, `terraform validate`, `terraform fmt`
**Target Platform**: AWS EKS and Kubernetes
**Project Type**: Terraform wrapper module with nested Linkerd submodules
**Performance Goals**: N/A; configuration-only plan-time behavior
**Constraints**: No consumer interface change; no chart version change
**Scale/Scope**: `modules/linkerd` and one new nested submodule

## Constitution Check

- **I. Shared source of truth**: No conflict detected between the
  `terraform-module-developer` skill guidance and repository-local rules.
- **II. Workflow enforcement**: **Deviation — see Process Note below.** This
  package was authored after implementation rather than before it.
- **III. Wrapper-first, safe interfaces**: The consumer input surface is
  unchanged. No new inputs are added to `modules/linkerd` or the root module; the
  certificates are an internal implementation detail. No requiredness semantics
  change, so no interface-widening approval is required.
- **IV. Evidence-first verification**: Formatting, validation, native tests,
  out-of-band certificate inspection, and a live cluster apply were all run. The
  one verification gap found in the process is recorded under Validation.
- **V. Documentation and compatibility**: READMEs regenerated through the
  repository's `terraform_docs` pre-commit hook. The change is backward
  compatible for module consumers; the operational impact on existing
  installations is recorded under Risks.
- **Modern capability classification**: **supported**. The chart already exposes
  the `crtPEM`/`keyPEM`/`caBundle` values for all three webhooks; this change only
  populates an interface the chart already supports.
- **Module-change gate**: this package contains `spec.md`, `plan.md`, and
  `tasks.md`.

### Process Note

Principle II requires the Speckit package to precede module edits. It did not
here: the work was implemented, verified, and merged into a branch first, and
this package was written afterwards to close the gate. It is therefore a record
of what was built rather than a plan that guided the build. The branch name also
does not follow the `NNN-slug` convention used by earlier packages, because it
was created before this package existed. Both facts are recorded rather than
hidden, per Principle IV.

## Project Structure

```text
modules/linkerd/
├── configs.tf
├── locals.tf
├── main.tf
├── versions.tf
├── README.md
├── modules/
│   ├── identity-certificates-and-keys/
│   └── webhook-certificates-and-keys/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
└── tests/
    ├── configs_crds.tftest.hcl
    └── webhook_certificates.tftest.hcl
specs/006-linkerd-webhook-certificates/
├── spec.md
├── plan.md
└── tasks.md
```

**Structure Decision**: Add the certificate generation as a sibling nested
submodule to `identity-certificates-and-keys`, matching the established layout,
rather than inlining the resources into `modules/linkerd`. Keep chart default
maps in `locals.tf`, matching the convention used by other modules in this
repository.

## Current State and Standards Assessment

- Starting module path: `modules/linkerd`.
- Related submodules in scope: `modules/linkerd/modules/identity-certificates-and-keys`
  (pattern reference and `required_version` alignment only).
- Current gap: the identity chain is generated with a 21-year validity, but the
  three webhook serving certificates are left to the chart, which issues them for
  one year with no rotation.
- Wrapper preservation: no consumer input is added; the certificates are internal.
- Repository automation changes: none.
- Layout convention: 12 modules in this repository keep general configuration
  locals in `locals.tf`; inline `locals` appear only in files bound to a single
  resource group. The chart default maps are general configuration, so they belong
  in `locals.tf`.
- Version constraint convention: the root module and the maintained submodules
  declare the Helm provider in object form with `~> 2.0`. `modules/linkerd` used
  the legacy shorthand `helm = ">= 2.0"`, which omits an explicit source and
  permits 3.x when the module is initialised standalone.

## Proposed File Changes

- Create `modules/linkerd/modules/webhook-certificates-and-keys/` with `main.tf`,
  `variables.tf`, `outputs.tf`, `versions.tf`, and `README.md`.
- Update `modules/linkerd/configs.tf` to invoke the new submodule.
- Create `modules/linkerd/locals.tf` holding the chart default maps.
- Update `modules/linkerd/main.tf` to pass module defaults and consumer configs as
  two separate `values[]` entries.
- Create `modules/linkerd/tests/webhook_certificates.tftest.hcl`.
- Update `modules/linkerd/versions.tf` and both submodule `versions.tf` files with
  pessimistic, explicitly sourced constraints.
- Regenerate the affected `README.md` files through the pre-commit hook.

## Secondary Changes in the Same Delivery

Bundled into this change because they touch the same files:

- **Remove the `cloudposse` deepmerge module.** Module defaults and consumer
  configs are passed as two `helm_release` `values[]` entries and merged by Helm.
  Verified equivalent to the previous behavior: nested maps deep-merge and lists
  are replaced. One difference: an explicit `null` in a later entry deletes the
  key under Helm, where deepmerge would set it to null. Nothing in this module
  relies on that.
- **Version constraint correction**, as described above.

## Risks and Approvals

- **Breaking changes for consumers**: none. No input, output, or default changes.
- **Interface widening**: none.
- **Operational risk on existing installations**: applying this replaces the
  chart-generated webhook certificates and rolls the control-plane release. The
  proxy injector is briefly unavailable during the apply, so it should not run
  concurrently with a deployment that depends on injection.
- **Key encoding risk**: the control-plane components do not all accept the same
  private key encoding. This was realised during a live apply, not during design;
  see Validation.
- **Private key exposure**: generated keys are stored in Terraform state and
  appear in cleartext in `helm_release.metadata` in plan output, because that
  provider attribute is computed and not marked sensitive. This is pre-existing
  behavior that already affected the identity issuer key and is not introduced
  here, but this change widens it to three more keys. Tracked separately for
  remediation via cert-manager.

## Validation

1. Run `terraform fmt -check -recursive` for the module tree.
2. Run `terraform validate` for the module and both submodules.
3. Run the native test suite and confirm certificate forwarding and the
   defaults/override precedence assertions pass.
4. Verify Helm's merge semantics independently against a scratch chart, covering
   both nested-map merging and list replacement.
5. Inspect generated certificates out-of-band: validity period, subject, subject
   alternative names, `caBundle` equality, and certificate/key pair match.
6. Apply against a live cluster and confirm the control-plane pod reaches full
   readiness.
7. Run pre-commit checks for all changed files.

### Verification Gap Found

Steps 1-5 all passed while the module still emitted an unusable private key
encoding. The out-of-band inspection confirmed the certificates were *correct*
without confirming they were *consumable*, and no plan-time or test-time check
could have caught it: the constraint lives in a control-plane binary, not in
Terraform or the chart. Step 6 caught it. The lesson recorded here is that for
material consumed by third-party components, a live apply is a required
verification step and cannot be substituted with static inspection.
