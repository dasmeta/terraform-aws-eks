# Feature Specification: Linkerd CRD Chart Configuration

**Feature Branch**: `005-linkerd-crds-config`  
**Created**: 2026-07-28  
**Status**: Approved  
**Input**: Expose optional Linkerd CRD Helm chart values through the root EKS
module and Linkerd child module so YAML consumers can explicitly enable
`installGatewayAPI` without changing existing defaults.

## User Scenarios & Testing

### User Story 1 - Configure Linkerd CRDs (Priority: P1)

As an EKS module consumer, I can provide values specifically for the
`linkerd-crds` Helm chart through the existing grouped `linkerd` input.

**Why this priority**: This unblocks consumers whose Linkerd installation needs
Gateway API CRDs while keeping cluster configuration declarative.

**Independent Test**: Configure `configs_crds.installGatewayAPI = true`, render
a Terraform plan, and confirm that the value reaches only the
`linkerd-crds` Helm release.

**Acceptance Scenarios**:

1. **Given** Linkerd is enabled, **When** a consumer supplies
   `linkerd.configs_crds.installGatewayAPI = true`, **Then** the CRD Helm
   release receives `installGatewayAPI = true`.
2. **Given** a consumer supplies CRD chart values, **When** Terraform plans the
   Linkerd module, **Then** control-plane and Viz values remain unchanged.

### User Story 2 - Preserve Existing Defaults (Priority: P2)

As an existing consumer, I can upgrade the EKS module without adding a new
Linkerd setting and retain the current chart-default behavior.

**Why this priority**: The shared module must not unexpectedly install
cluster-wide Gateway API CRDs in existing environments.

**Independent Test**: Omit `configs_crds`, validate the module, and confirm the
input resolves to an empty object without changing the selected chart versions
or enablement defaults.

**Acceptance Scenarios**:

1. **Given** an existing `linkerd` configuration, **When** `configs_crds` is
   omitted, **Then** Terraform accepts the configuration.
2. **Given** the entire `linkerd` input is omitted, **When** Terraform evaluates
   module defaults, **Then** Linkerd remains enabled with the current chart
   versions and an empty CRD configuration.

### Edge Cases

- An empty `configs_crds = {}` must be valid and preserve chart defaults.
- Arbitrary chart-supported nested values must pass through without the wrapper
  attempting to validate or reinterpret them.
- Setting `crds_create = false` may leave the values unused because the CRD
  release count is zero; this existing enablement behavior remains unchanged.

## Requirements

### Functional Requirements

- **FR-001**: The root `linkerd` object MUST expose an optional
  `configs_crds` attribute with default `{}`.
- **FR-002**: The root module MUST forward `linkerd.configs_crds` to the
  Linkerd child module.
- **FR-003**: The Linkerd child module MUST expose a `configs_crds` input with
  default `{}`.
- **FR-004**: The child module MUST pass the encoded CRD configuration only to
  `helm_release.this_crds`.
- **FR-005**: Existing consumers that omit `configs_crds` MUST remain valid.
- **FR-006**: Documentation and an executable example MUST demonstrate
  `installGatewayAPI = true`.
- **FR-007**: Automated validation MUST cover explicit and omitted CRD
  configuration.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A consumer can express
  `linkerd.configs_crds.installGatewayAPI = true` without editing the module.
- **SC-002**: Terraform formatting and validation checks pass across the
  repository.
- **SC-003**: A targeted test proves the explicit value is encoded in the CRD
  Helm release.
- **SC-004**: No existing Linkerd default, chart version, or enablement flag is
  changed.

## Assumptions

- Linkerd chart `2025.10.7` supports the `installGatewayAPI` value.
- Helm chart validation remains responsible for the semantics of arbitrary
  `configs_crds` keys.
- The EKS root module remains an opinionated wrapper and exposes one grouped
  CRD values map rather than individual chart flags.
