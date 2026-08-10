# Feature Specification: External Secrets on EKS Pod Identity with Role Chaining

**Feature Branch**: `external-secret-improvements`
**Created**: 2026-08-03
**Status**: Implemented
**Input**: Move the External Secrets controller off IAM users and static access keys onto EKS
Pod Identity, granting Secrets Manager access through per-store IAM roles the controller
assumes, and expose the controller identity so the `external-secret-store` module can be wired
to it.

## Context

The controller previously authenticated with an IAM user whose access keys were written into a
Kubernetes Secret and referenced from the `SecretStore` via `secretRef`. Long-lived static
credentials sat in cluster Secrets and in Terraform state, and each store needed its own user.

This change replaces that with EKS Pod Identity plus IAM role chaining: the controller runs
under a base role that holds **no** Secrets Manager permissions and may only `sts:AssumeRole`
the per-store roles, each scoped to its own secret name prefix. The paired changes in the
`external-secret-store` module are specified separately in that repository.

## User Scenarios & Testing

### User Story 1 - No Static Credentials (Priority: P1)

As a platform engineer, the External Secrets controller reaches AWS Secrets Manager without any
IAM user or long-lived access key existing anywhere.

**Why this priority**: Static keys in cluster Secrets and Terraform state are the security
problem this change exists to remove.

**Independent Test**: After an apply, no IAM user or access key exists for external-secrets and
no `*-awssm-secret` Secret remains in the cluster, while secrets still sync.

**Acceptance Scenarios**:

1. **Given** the module is applied, **When** the controller reads a secret, **Then** it does so
   using credentials obtained from its Pod Identity association.
2. **Given** the controller's base role, **When** its policies are inspected, **Then** it grants
   only `sts:AssumeRole` on the per-store role name prefix and no Secrets Manager actions.

### User Story 2 - Credentials Reach Running Pods (Priority: P1)

As an operator upgrading an existing cluster, secret synchronisation keeps working across the
upgrade without me discovering a broken store later.

**Why this priority**: Pod Identity injects credentials at pod admission time. Pods already
running when the identity is created never receive them, and the failure is silent because
previously synced Kubernetes Secrets retain their values.

**Independent Test**: Upgrade a cluster whose controller pods predate the association, then
force an ExternalSecret refetch and confirm it reports ready.

**Acceptance Scenarios**:

1. **Given** the controller's identity is created or changed, **When** the module applies,
   **Then** the controller pods are replaced so the credential environment variables are
   injected.
2. **Given** a Pod Identity association exists, **When** the cluster is inspected, **Then** the
   Pod Identity Agent is installed, since an association delivers nothing without it.

### User Story 3 - Upgrade Without Reinstalling the Chart (Priority: P1)

As an operator, upgrading from the previous module version does not uninstall external-secrets.

**Why this priority**: The release moved from a wrapper module to a direct resource. Left
unhandled, Terraform destroys and recreates it, leaving every ExternalSecret unreconciled while
the controller is absent.

**Independent Test**: Plan an upgrade from the previous released version and confirm the release
is reported as moved, not destroyed.

**Acceptance Scenarios**:

1. **Given** state from the previous version, **When** the upgrade is planned, **Then** the Helm
   release is re-pointed to its new address rather than destroyed and created.

### User Story 4 - Wiring the Store Module (Priority: P2)

As a consumer, I can pass the controller identity to each `external-secret-store` call without
hand-copying ARNs.

**Independent Test**: Reference the EKS module output for `controller_role_arn` and
`store_role_name_prefix` in a store module call and apply.

**Acceptance Scenarios**:

1. **Given** External Secrets is enabled, **When** the root outputs are read, **Then** they
   expose the controller role ARN and the store role name prefix.
2. **Given** the prefix differs between the controller and a store, **When** the store is used,
   **Then** the controller cannot assume that store's role - the two must agree.

### Edge Cases

- Existing consumers pinning the old chart-version or namespace variables must keep working.
- Disabling External Secrets must not create the controller identity.
- IRSA remains available for clusters that cannot use Pod Identity; it has the same
  credentials-at-admission problem and needs the same pod replacement.
- The store role name prefix is a wildcard grant: any role matching it is assumable by the
  controller, so the prefix must not be broadened to something generic.

## Requirements

### Functional Requirements

- **FR-001**: The controller's AWS identity MUST be provisioned through an EKS Pod Identity
  association by default, with IRSA available as an alternative.
- **FR-002**: The controller's base role MUST NOT grant Secrets Manager access directly; it MUST
  only permit assuming roles matching the configured store role name prefix.
- **FR-003**: No IAM user or static access key may be created for External Secrets.
- **FR-004**: The Pod Identity Agent addon MUST be installed by default.
- **FR-005**: The controller's identity MUST be created before its pods start, and any change to
  that identity MUST cause the controller pods to be replaced.
- **FR-006**: Upgrading from the previous released version MUST NOT uninstall the Helm release.
- **FR-007**: The module MUST expose the controller role ARN and store role name prefix as
  outputs.
- **FR-008**: Previously supported top-level External Secrets variables MUST continue to work,
  taking precedence over the grouped variable when explicitly set.
- **FR-009**: The chart source MUST accept either a Helm repository or a direct archive URL, and
  controller/webhook/cert-controller images MUST be overridable.

### Non-Functional Requirements

- **NFR-001**: Provider constraints MUST be pessimistic and explicitly sourced.
- **NFR-002**: The upgrade path MUST be documented, including the cross-repository ordering and
  validation that distinguishes a working store from one serving stale cached values.

## Success Criteria

### Measurable Outcomes

- **SC-001**: After an apply, no IAM user, access key, or static-credential Secret exists for
  External Secrets, and every ExternalSecret reports ready.
- **SC-002**: A forced refetch of an ExternalSecret succeeds, proving live credentials rather
  than cached values.
- **SC-003**: An upgrade plan from the previous version shows the Helm release moved, not
  destroyed.
- **SC-004**: Terraform formatting, validation, and static analysis pass.
- **SC-005**: No existing consumer input is removed or changed in a way that breaks an existing
  configuration.

## Assumptions

- The target clusters support EKS Pod Identity.
- Consumers upgrade the EKS module before the store module; between those two steps stores still
  authenticate with their existing static keys and keep working.
- Terraform state remains the system of record for the IAM resources created here.
