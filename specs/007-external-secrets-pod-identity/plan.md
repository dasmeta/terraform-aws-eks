# Implementation Plan: External Secrets on EKS Pod Identity with Role Chaining

**Branch**: `external-secret-improvements` | **Date**: 2026-08-03 |
**Spec**: `specs/007-external-secrets-pod-identity/spec.md`

## Summary

Rewrite `modules/external-secrets` to install the chart through a direct `helm_release` and to
provision the controller's AWS identity as an EKS Pod Identity association (IRSA optional). The
controller's base role holds no Secrets Manager access and may only assume the per-store roles.
Expose the controller identity through root outputs so `external-secret-store` calls can be
wired to it, and document the two-repository upgrade path.

## Technical Context

**Language/Version**: Terraform `~> 1.3`
**Primary Dependencies**: AWS provider `>= 5.0, < 7.0`, Helm provider `~> 2.0`, external-secrets
chart 2.8.0
**Storage**: Terraform state holds the IAM role and association
**Testing**: `terraform validate`, `terraform fmt`, tflint, tfsec, checkov, chart rendering
**Target Platform**: AWS EKS
**Project Type**: Terraform wrapper module with a nested External Secrets submodule
**Constraints**: No consumer interface may be removed; no chart reinstall on upgrade
**Scale/Scope**: `modules/external-secrets`, root wiring, one example

## Constitution Check

- **I. Shared source of truth**: No conflict found between the `terraform-module-developer` skill
  and repository-local rules.
- **II. Workflow enforcement**: **Deviation - see Process Note.** Authored after implementation.
- **III. Wrapper-first, safe interfaces**: The grouped `external_secrets` object replaces a set
  of unused fields with ones the module actually consumes, matching the shape already used by
  `alb_load_balancer_controller`. The previously released top-level variables are retained as
  deprecated inputs that still win when set, so no consumer contract is broken. No requiredness
  changes, so no interface-widening approval was required.
- **IV. Evidence-first verification**: Formatting, validation, tflint, tfsec, checkov, chart
  rendering, and a live cluster apply were all run. Gaps recorded under Validation.
- **V. Documentation and compatibility**: Upgrade guide entry added covering both repositories;
  READMEs regenerated through the repository's `terraform_docs` hook.
- **Modern capability classification**: **supported**. EKS Pod Identity is the current AWS
  mechanism for granting workload credentials and is not deprecated; IRSA is retained as the
  fallback for clusters that cannot use it.
- **Module-change gate**: this package contains `spec.md`, `plan.md`, and `tasks.md`.

### Process Note

Principle II requires the Speckit package to precede module edits. It did not here: the module
work was implemented and verified first, and this package was written afterwards to close the
gate. It records what was built rather than a plan that guided the build. The branch name also
does not follow the `NNN-slug` convention. The package is numbered `007` because `006` is already
taken on `origin/main` by the Linkerd webhook-certificate change.

## Project Structure

```text
locals.tf
main.tf
variables.tf
outputs.tf
modules/external-secrets/
├── main.tf
├── locals.tf
├── iam.tf
├── data.tf
├── moved.tf
├── variables.tf
├── outputs.tf
├── version.tf
└── README.md
examples/eks-with-karpenter-and-external-secret/
specs/007-external-secrets-pod-identity/
├── spec.md
├── plan.md
└── tasks.md
```

**Structure Decision**: Keep the repository's existing root/nested-module layout. IAM resources
live in `iam.tf`, data sources in `data.tf`, derived values in `locals.tf`, and state moves in a
dedicated `moved.tf` so refactor bookkeeping is separate from the resources themselves.

## Current State and Standards Assessment

- Starting module path: `modules/external-secrets`, plus root wiring.
- Prior state: the chart was installed through the `terraform-module/release/helm` wrapper and
  the module created no IAM resources at all; each store carried its own IAM user and static
  keys.
- Grouped-variable convention: `alb_load_balancer_controller` nests IAM concerns under an `iam`
  object with inline per-field comments. `external_secrets` follows the same shape.
- Addon convention: `default_addons` is a typed object of always-installed core addons with no
  per-addon toggle. `eks-pod-identity-agent` is added there rather than behind conditional
  logic, because Pod Identity is intended as the default mechanism going forward.
- Region convention: modules take an optional `region` input, defaulting to a lookup, with the
  data source count-gated on the input being null.

## Proposed File Changes

- Rewrite `modules/external-secrets/main.tf` to a direct `helm_release` with layered values.
- Add `iam.tf` (base role, assume-store-roles policy, Pod Identity association), `data.tf`,
  `locals.tf`, `moved.tf`, and expand `variables.tf`/`outputs.tf`.
- Wire the grouped `external_secrets` variable through root `main.tf`/`locals.tf`, retaining the
  deprecated top-level variables via `coalesce`.
- Add `eks-pod-identity-agent` to `var.default_addons`.
- Add an `external_secrets` root output carrying the controller role ARN and store role prefix.
- Update the example to wire the store module to those outputs.
- Add the `>= 2.28.0` upgrade guide entry.

## Risks and Approvals

- **Breaking changes for consumers**: none intended. Deprecated variables still work; the store
  module's `controller_role_arn` becomes required, which is covered by the upgrade guide as an
  explicit step.
- **Destroyed resources**: the store IAM users, access keys and static-credential Secrets are
  destroyed. This is the intent of the change, not a regression.
- **Silent-failure risk**: a store with broken credentials keeps serving its last synced Secret,
  so the documented validation includes a forced refetch rather than relying on workload health.
- **Wildcard trust**: the controller holds `sts:AssumeRole` on a role-name wildcard. The prefix
  must stay specific; broadening it would widen what the controller can assume.
- **Partition hardcoding**: ARNs are built with the `aws` partition, consistent with the rest of
  this repository, so GovCloud/China are unsupported here as elsewhere. Noted, not changed.

## Validation

1. `terraform fmt -check -recursive` across both repositories.
2. `terraform validate` for the root, the submodule, and the example.
3. `tflint`, `tfsec`, and `checkov` against the changed modules.
4. Render the consuming chart and confirm the ExternalSecret's store reference, kind, apiVersion
   and remote key match what the store module creates.
5. Render the external-secrets chart with the module's layered values and confirm the identity
   annotation reaches all three pod templates without dropping the image overrides.
6. Apply against a live cluster and confirm secrets sync.

### Verification Gaps Found

- Static checks alone did not surface that the controller pods keep stale credentials after the
  identity changes; that appeared only on a live upgrade, as `AccessDenied` on `sts:AssumeRole`
  which cleared after restarting the three deployments. The fix (annotating the pod templates
  with the identity) was derived from that observation, and the upgrade guide keeps the manual
  restart as the documented fallback.
- No `terraform plan` was run during authoring because no AWS credentials were available in the
  authoring environment; the upgrade behaviour of the `moved` block was reasoned from the
  consumer-supplied plan output rather than reproduced locally.
