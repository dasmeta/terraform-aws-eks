# Implementation Plan: AWS Load Balancer Controller Identity Ordering

**Branch**: `008-alb-controller-identity-ordering` | **Date**: 2026-08-24 |
**Spec**: `specs/008-alb-controller-identity-ordering/spec.md`

## Summary

Reorder `modules/aws-load-balancer-controller` so the controller's AWS identity is complete
before its pods start: give the Helm release explicit dependencies on the policy attachment and
the Pod Identity association, remove the inverted `depends_on` from the association, insert a
bounded wait for IAM propagation, and stamp the identity onto the pod template so later identity
changes roll the deployment. Expose the wait as `iam.propagation_delay` and document the
behaviour in the submodule header and the root upgrade guide.

## Technical Context

**Language/Version**: Terraform `~> 1.3`
**Primary Dependencies**: AWS provider `> 5.0, < 7.0`, Helm provider `~> 2.0`, new Time provider
`~> 0.9`, aws-load-balancer-controller chart 3.x
**Storage**: Terraform state holds the IAM role, policy, attachment, association and the wait
**Testing**: `terraform validate`, `terraform plan` against the submodule in each attachment
mode, `terraform graph` edge inspection, `helm template` rendering, pre-commit hooks
**Target Platform**: AWS EKS
**Project Type**: Terraform wrapper module with a nested load balancer controller submodule
**Constraints**: No consumer interface may be removed; no resource may be replaced on upgrade
**Scale/Scope**: `modules/aws-load-balancer-controller`, one root variable, root upgrade guide

## Constitution Check

- **I. Shared source of truth**: No conflict found between the `terraform-module-developer` skill
  and repository-local rules.
- **II. Workflow enforcement**: **Deviation - see Process Note.** Authored after implementation.
- **III. Wrapper-first, safe interfaces**: One optional field is added to the existing
  `iam` object, which already groups IAM concerns. It has a working default, so no requiredness
  semantics change and no interface-widening approval was required. Nothing is removed or renamed.
- **IV. Evidence-first verification**: Formatting, validation, per-mode plans, graph inspection
  and chart rendering were all run; the live-cluster confirmation came from the reporter. Gaps
  recorded under Validation.
- **V. Documentation and compatibility**: Submodule header documents the credential-delivery
  behaviour; a `>= 2.30.0` upgrade guide entry covers the one-time rollout and the new provider
  requirement; READMEs regenerated through the repository's `terraform_docs` hook.
- **Modern capability classification**: **supported**. IRSA and EKS Pod Identity are both current
  AWS mechanisms; this change does not alter which is used, only when it is wired.
- **Module-change gate**: this package contains `spec.md`, `plan.md`, and `tasks.md`.

### Process Note

Principle II requires the Speckit package to precede module edits. It did not here: the defect was
reported from a live cluster, diagnosed and fixed first, and this package was written afterwards
to close the gate. It records what was built rather than a plan that guided the build. The
package is numbered `008` because `007` is already taken by the External Secrets Pod Identity
change.

## Project Structure

```text
variables.tf
main.tf
modules/aws-load-balancer-controller/
├── main.tf
├── iam.tf
├── locals.tf
├── variables.tf
├── versions.tf
└── README.md
specs/008-alb-controller-identity-ordering/
├── spec.md
├── plan.md
└── tasks.md
```

**Structure Decision**: Keep the repository's existing root/nested-module layout. The ordering
resources stay in `iam.tf` next to the identity they gate, the derived pod annotation stays in
`locals.tf` with the rest of the chart values, and the release's `depends_on` stays in `main.tf`
where the release is declared.

## Current State and Standards Assessment

- Starting module path: `modules/aws-load-balancer-controller`, plus one root variable.
- Prior state: `helm_release` depended only on `aws_iam_role`, through the role ARN embedded in
  the service account annotation. `aws_iam_role_policy_attachment` had no edge to the release.
  `aws_eks_pod_identity_association` depended on the release, which is the reverse of the order
  its credential delivery requires.
- Precedent: `modules/external-secrets` already orders its association before its release and
  stamps the identity onto its pod templates as `checksum/aws-identity`, with the reasoning
  recorded in the code. This change reuses that pattern and its annotation key rather than
  inventing a second convention.
- Grouped-variable convention: IAM concerns are nested under an `iam` object with inline
  per-field comments, mirrored between the submodule and the root variable.
- Provider convention: submodules declare their own `required_providers` with pessimistic
  constraints. The Time provider needs no configuration, so no root provider block is required.

## Proposed File Changes

- `modules/aws-load-balancer-controller/main.tf`: add `depends_on` on the policy attachment, the
  Pod Identity association and the propagation wait; document credential delivery in the header.
- `modules/aws-load-balancer-controller/iam.tf`: drop the association's `depends_on` on the Helm
  release; add `time_sleep.iam_propagation`, gated on the delay not being `"0s"` and triggered by
  the identity values so it does not recur.
- `modules/aws-load-balancer-controller/locals.tf`: derive `identity_annotation` from the role
  ARN, the attachment id and the attachment method; add it to the chart values as
  `podAnnotations`.
- `modules/aws-load-balancer-controller/variables.tf`: add `iam.propagation_delay` with a default
  and a duration-format validation.
- `modules/aws-load-balancer-controller/versions.tf`: declare the Time provider.
- Root `variables.tf`: mirror `propagation_delay` into `alb_load_balancer_controller.iam`.
- Root `main.tf`: add the `>= 2.30.0` upgrade guide entry.
- Regenerate both affected `README.md` files.

## Risks and Approvals

- **Breaking changes for consumers**: none. The new field is optional with a default, and no
  address, input or output is removed or renamed.
- **Replaced resources**: none. Adding and removing `depends_on` reorders the graph without
  forcing replacement, and the association keeps its address.
- **One-time rollout on upgrade**: existing installs gain a pod annotation and therefore roll the
  controller once. Brief and self-healing; it also clears any controller currently stuck on bad
  credentials, so it is remediation rather than regression. Documented in the upgrade guide.
- **New provider dependency**: `hashicorp/time` is added to the submodule, so consumers need
  `terraform init -upgrade` to refresh their lock file. Documented in the upgrade guide.
- **Apply duration**: fresh installs wait `iam.propagation_delay` once. Set to `"0s"` to opt out.
- **Externally managed associations**: with `attachment_method = null` the module cannot order an
  association it does not create. Called out in the spec's edge cases; no code change possible.

## Validation

1. `terraform fmt` through the repository's `terraform_fmt` pre-commit hook.
2. `terraform validate` for the submodule and the root module.
3. `terraform plan` against the submodule in all three configurations: IRSA default, Pod Identity,
   and `propagation_delay = "0s"`.
4. `terraform graph` to confirm the release is ordered after the wait, and the wait after both the
   policy attachment and the association.
5. A rejected-input check confirming an invalid duration fails variable validation.
6. `helm template` against the pinned chart to confirm `podAnnotations` reaches the controller's
   pod template.
7. Regenerate documentation through the `terraform_docs` pre-commit hook.

### Verification Gaps Found

- The original defect was reported from a live cluster, not surfaced by static analysis. Neither
  `validate` nor `plan` flags a missing `depends_on`, because the configuration is valid either
  way; only the graph shows it. Graph inspection was therefore added to the validation steps
  rather than relying on plan output.
- No live apply was performed from this environment. The reporter confirmed the fixed module
  behaves correctly on their cluster; the timing margin between the wait and the controller's
  first AWS call was reasoned about rather than measured.
- The propagation delay cannot be proven sufficient by static means. It is a mitigation on top of
  the ordering fix, not the fix itself, and is configurable for that reason.
