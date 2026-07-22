# Implementation Plan: Upgrade AWS Load Balancer Controller Chart Version

**Branch**: `003-upgrade-alb-controller-version` | **Date**: 2026-07-21 | **Spec**: `specs/003-upgrade-alb-controller-version/spec.md`
**Input**: Feature specification from `/specs/003-upgrade-alb-controller-version/spec.md`

## Summary

Bump the `aws-load-balancer-controller` module default chart `version` from `3.3.0` to `3.4.2` (latest stable on `eks-charts`). The controller image follows the chart `appVersion` automatically (`v3.4.2`) because `image.tag` defaults to null. The vendored `iam-policy.json` was verified equivalent to the upstream controller policy for both `v3.3.0` and `v3.4.2`, so no IAM change is required. Update README and the basic example to match. Backward-compatible; consumers who pin the version are unaffected.

## Technical Context

**Terraform/OpenTofu Version**: Terraform `~> 1.3`  
**Providers / Upstream Modules**: `hashicorp/helm (~> 2.0)`, `aws (> 5.0, < 7.0)`, `aws-load-balancer-controller` Helm chart from `eks-charts`  
**Target Module Path**: `modules/aws-load-balancer-controller`  
**Examples / Tests in Scope**: `modules/aws-load-balancer-controller/examples/basic`  
**Automation Gates**: `pre-commit` hooks (`terraform_fmt`, `terraform_docs`, file hygiene), repo CI checks for Terraform module changes  
**Target Platform**: Amazon EKS clusters (the controller manages AWS Application/Network Load Balancers; a full functional test requires a real EKS cluster with AWS integration)  
**Constraints**: Preserve current default behavior aside from the version number; no interface or breaking changes; keep the vendored IAM policy in sync with the deployed controller version  
**Scale/Scope**: One module plus its README and basic example

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] Change stays within one coherent module responsibility and the current repository scope.
- [x] Consumer interface remains opinionated; no interface widening (defaults-only change).
- [x] `README.md` and `examples/` updates are listed for the version change.
- [x] `versions.tf` provider compatibility reviewed — unchanged.
- [x] Breaking changes / weakened defaults: none.

Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-upgrade-alb-controller-version/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── module-interface.md
└── tasks.md
```

### Source Code (repository root)

```text
modules/aws-load-balancer-controller/
├── variables.tf                    # chart.version default 3.3.0 -> 3.4.2
├── README.md                       # generated input table updated to 3.4.2
├── iam-policy.json                 # verified equivalent to upstream v3.4.2 (unchanged)
└── examples/
    └── basic/
        └── 1-example.tf            # chart version 3.3.0 -> 3.4.2
```

**Structure Decision**: Keep all work localized to `modules/aws-load-balancer-controller` and its basic example. No new files.

## Phase 0: Research Plan

1. Confirm the latest stable chart version on `eks-charts` and the controller image it maps to (chart `appVersion`).
2. Compare the upstream controller IAM policy between the previous and target versions to detect any permission delta.
3. Confirm the vendored `iam-policy.json` matches the upstream policy for the target version.
4. Define validation: `terraform validate` for module/example plus the IAM-policy equivalence check.

## Phase 1: Design Outputs

- `research.md`: Version target, chart→image mapping, and the IAM-policy equivalence finding.
- `data-model.md`: The chart-version baseline and IAM-policy contract entities.
- `contracts/module-interface.md`: Confirmation of an unchanged interface and the single default delta.
- `quickstart.md`: Maintainer execution + verification flow.

Agent context regeneration is intentionally skipped (not explicitly requested).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | Defaults-only version bump with verified IAM parity | N/A |
