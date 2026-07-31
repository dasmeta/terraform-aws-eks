# Feature Specification: Long-Lived Linkerd Admission Webhook Certificates

**Feature Branch**: `fix-linkerd-webhook-cert-expiry`
**Created**: 2026-07-31
**Status**: Implemented
**Input**: Generate long-lived TLS serving certificates for the three
`linkerd-control-plane` admission webhooks in Terraform, so they stop silently
expiring one year after installation the way the Helm chart's own self-generated
certificates do.

## Context

`modules/linkerd` already generates 21-year certificates for the mesh mTLS
identity chain through `modules/identity-certificates-and-keys`, but nothing
covered the admission webhook serving certificates. Those were left entirely to
the chart, which self-generates them with a 1-year validity and no rotation.

Because all three webhooks default to `failurePolicy: Ignore`, expiry produces
no error anywhere: the API server simply stops calling the webhook. For the
proxy injector this means annotated pods silently stop receiving the
`linkerd-proxy` sidecar. This was observed in a cluster where the condition had
persisted undetected for months, leaving dozens of workloads unmeshed.

## User Scenarios & Testing

### User Story 1 - Webhook Certificates Outlive the Install (Priority: P1)

As an EKS module consumer running Linkerd, my admission webhooks keep working
well beyond the first year without manual certificate rotation.

**Why this priority**: Expiry silently disables proxy injection and the two
validating webhooks, with no error surfaced to operators.

**Independent Test**: Install the module, read the three webhook TLS secrets from
the cluster, and confirm each certificate's `notAfter` is roughly 21 years out
rather than one year.

**Acceptance Scenarios**:

1. **Given** Linkerd is enabled, **When** the control-plane release is created,
   **Then** each webhook secret contains a certificate valid for the configured
   `validity_period_hours` rather than the chart's 1-year default.
2. **Given** the certificates are supplied by the module, **When** the API server
   dials a webhook, **Then** the certificate validates against the webhook's
   `caBundle`.

### User Story 2 - Control Plane Starts Cleanly (Priority: P1)

As an EKS module consumer, the supplied certificates are consumable by every
control-plane component that reads them, not just some of them.

**Why this priority**: The policy controller and the Go-based webhooks do not
accept the same private key encodings. A key that satisfies one crashes the
other, and the failure takes the whole `linkerd-destination` pod down.

**Independent Test**: Apply the module and confirm the `linkerd-destination` pod
reaches a fully ready state with no container restarts.

**Acceptance Scenarios**:

1. **Given** the module supplies `policyValidator.keyPEM`, **When** the policy
   controller starts, **Then** it loads the key and serves on its gRPC port.
2. **Given** the module supplies `proxyInjector.keyPEM` and
   `profileValidator.keyPEM`, **When** those components start, **Then** they load
   the same key encoding without error.

### User Story 3 - Existing Consumers Are Unaffected (Priority: P2)

As an existing consumer, I can upgrade without changing my configuration and
without my own Helm values being overridden.

**Why this priority**: The change alters how module defaults are merged with
consumer-supplied values, so the override contract must be preserved exactly.

**Independent Test**: Supply `configs` overriding one nested key and confirm the
sibling keys from the module defaults survive.

**Acceptance Scenarios**:

1. **Given** a consumer supplies `configs`, **When** Terraform plans the module,
   **Then** those values take precedence over the module defaults.
2. **Given** a consumer overrides one key inside a nested map, **When** the values
   are merged, **Then** unrelated sibling keys from the defaults are retained.

### Edge Cases

- A consumer overriding `proxyInjector.crtPEM`/`keyPEM` directly through
  `configs` must win over the generated defaults.
- Existing installations already hold chart-generated certificates; applying this
  change replaces them and rolls the control plane, briefly interrupting
  admission.
- Certificate replacement is not a rotation mechanism: the certificates are
  regenerated only if the Terraform state holding them is lost.

## Requirements

### Functional Requirements

- **FR-001**: The module MUST generate a TLS serving certificate and key for each
  of the `proxyInjector`, `profileValidator`, and `policyValidator` webhooks.
- **FR-002**: Certificate validity MUST default to `187600` hours (>21 years),
  matching the existing identity certificate default.
- **FR-003**: Each certificate MUST carry a subject and subject alternative names
  covering the Kubernetes Service name the chart hardcodes for that webhook, in
  its bare, namespaced, `.svc`, and `.svc.cluster.local` forms.
- **FR-004**: Each webhook's `caBundle` MUST be set to its own certificate, so
  the self-signed certificate acts as its own trust bundle.
- **FR-005**: Private keys MUST be emitted in an encoding that every consuming
  control-plane component can parse, including the Rust-based policy controller.
- **FR-006**: Generated values MUST be forwarded to the control-plane Helm
  release under the exact value keys the chart expects.
- **FR-007**: Consumer-supplied `configs` MUST continue to take precedence over
  module defaults, with nested maps deep-merged rather than replaced.
- **FR-008**: The module output carrying certificate material MUST be marked
  sensitive.
- **FR-009**: Automated validation MUST cover certificate forwarding and the
  defaults/consumer-override precedence contract.

### Non-Functional Requirements

- **NFR-001**: The consumer-facing input surface MUST NOT widen; no new inputs are
  added to `modules/linkerd` or the root module.
- **NFR-002**: Provider and Terraform version constraints MUST be pessimistic and
  explicitly sourced.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Webhook certificates in a freshly applied cluster expire roughly 21
  years out, not one year.
- **SC-002**: `linkerd check` passes the `linkerd-webhooks-and-apisvc-tls`
  category, and an annotated pod receives the `linkerd-proxy` sidecar.
- **SC-003**: The `linkerd-destination` pod reaches full readiness with no
  container restarts.
- **SC-004**: Terraform formatting, validation, and native tests pass.
- **SC-005**: No existing consumer input, default, or chart version changes.

## Assumptions

- The `linkerd-control-plane` chart at the pinned version reads
  `proxyInjector`, `profileValidator`, and `policyValidator` `crtPEM`/`keyPEM`/
  `caBundle` values, and self-generates only when they are empty.
- The Kubernetes Service names for the three webhooks are fixed by the chart and
  not derived from the Helm release name.
- Terraform state is the system of record for these certificates; protecting that
  state is a deployment concern outside this module.
- A 21-year validity is an accepted interim measure. Externalising certificate
  management to cert-manager, which would provide real rotation and keep private
  keys out of Terraform, is tracked separately.
