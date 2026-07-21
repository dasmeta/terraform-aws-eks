# Feature Specification: Upgrade AWS Load Balancer Controller Chart Version

**Feature Branch**: `003-upgrade-alb-controller-version`  
**Created**: 2026-07-21  
**Status**: Draft  
**Input**: User description: "upgrade the aws-load-balancer-controller module chart default to the latest stable release (3.3.0 -> 3.4.2), confirm the vendored IAM policy still matches the target controller version, and keep the change backward-compatible."

## Module Context *(mandatory)*

- **Target Module Path**: `modules/aws-load-balancer-controller`
- **Related Files In Scope**: `modules/aws-load-balancer-controller/variables.tf`, `modules/aws-load-balancer-controller/README.md`, `modules/aws-load-balancer-controller/examples/basic/1-example.tf`, `modules/aws-load-balancer-controller/iam-policy.json` (verification only)
- **Upstream Baseline**: `aws-load-balancer-controller` Helm chart from `https://aws.github.io/eks-charts`; vendored IAM policy from the upstream controller release
- **Requested Interface Change**: Default chart `version` moves `3.3.0 -> 3.4.2`. No input/output shape changes
- **Breaking Change / Interface Widening**: None. Backward-compatible default bump; consumers who pin the chart version are unaffected

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consume the up-to-date controller chart by default (Priority: P1)

As a platform engineer, I can consume the module with its default chart version and get the current stable AWS Load Balancer Controller (chart `3.4.2`, controller image `v3.4.2`) without pinning a version myself.

**Why this priority**: Version freshness keeps the controller on a supported, patched release; this is the core purpose of the change.

**Independent Test**: Plan the `examples/basic` configuration with defaults and confirm the chart version resolves to `3.4.2` and the controller image follows the chart's `appVersion`.

**Acceptance Scenarios**:

1. **Given** a consumer using defaults, **When** the module is planned, **Then** the chart version resolves to `3.4.2`.
2. **Given** a consumer that pins `chart.version`, **When** the module is planned, **Then** the pinned version is honored unchanged.

---

### User Story 2 - IAM policy stays correct for the new controller version (Priority: P2)

As a platform engineer, I can trust that the vendored IAM policy grants exactly the permissions the target controller version requires, so the controller functions without over- or under-privileged access.

**Why this priority**: An ALB controller upgrade most commonly breaks when required IAM permissions change between versions; this must be verified explicitly.

**Independent Test**: Compare the vendored `iam-policy.json` against the upstream controller policy for the target version and confirm they match.

**Acceptance Scenarios**:

1. **Given** the target controller version, **When** the vendored policy is compared to the upstream policy for that version, **Then** they are equivalent (no missing or extra permissions).
2. **Given** no IAM permission delta between the previous and target controller versions, **When** the chart version is bumped, **Then** no IAM policy change is required.

### Edge Cases

- What happens for consumers who pin `chart.version`? The pin wins; the new default does not force an upgrade.
- What happens to the controller image? `image.tag` defaults to null, so the chart's default image (matching its `appVersion`) is used — the image follows the chart bump automatically.
- What if a future controller version DOES change required IAM permissions? The vendored `iam-policy.json` must be refreshed from the upstream policy for that version as part of the bump.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The module MUST default `chart.version` to `3.4.2`.
- **FR-002**: The controller image MUST continue to follow the chart default when `image.tag` is unset (no separate image pin introduced).
- **FR-003**: The vendored `iam-policy.json` MUST be verified equivalent to the upstream controller policy for the target version; it is updated only if a delta exists.
- **FR-004**: `README.md` and `examples/basic` MUST reflect the new default version.
- **FR-005**: The change MUST preserve existing inputs/outputs; consumers pinning the version MUST be unaffected.

### Compatibility & Delivery Requirements

- **CDR-001**: The target module path and the example/verification files in scope are identified.
- **CDR-002**: The upstream chart (`eks-charts`) and upstream controller IAM policy are the authoritative sources for the version and permission verification.
- **CDR-003**: Verification includes `terraform validate` for the module/example and an IAM-policy equivalence check against the upstream policy for the target version.
- **CDR-004**: No downstream migration is required; the change is a backward-compatible default bump.

### Key Entities *(include if feature involves data or structured configuration)*

- **Chart Version Baseline**: The default chart version (`3.4.2`) that also determines the controller image via the chart `appVersion`.
- **IAM Policy Contract**: The vendored permission set that must match the upstream controller policy for the deployed version.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Planning the example with defaults resolves the chart to `3.4.2` with no undocumented manual steps.
- **SC-002**: `terraform validate` passes for the module and `examples/basic`.
- **SC-003**: The vendored IAM policy is confirmed equivalent to the upstream policy for the target controller version.
- **SC-004**: README and example reflect the new default version.
