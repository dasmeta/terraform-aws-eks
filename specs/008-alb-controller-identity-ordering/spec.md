# Feature Specification: AWS Load Balancer Controller Identity Ordering

**Feature Branch**: `008-alb-controller-identity-ordering`
**Created**: 2026-08-24
**Status**: Implemented
**Input**: On a fresh install of the `aws-load-balancer-controller` submodule, a newly created
Ingress reports missing IAM permissions for actions such as listing load balancers even though
the policy is attached to the role. Restarting the controller pods resolves it and the ALB is
created. Remove the cause so fresh installs no longer need a manual restart.

## Context

The controller obtains its AWS credentials exactly once, when its pod starts. With IRSA the
annotated service account is bound into the pod's projected service account token at pod
creation; with EKS Pod Identity the agent injects the credential environment variables at pod
admission. Neither mechanism re-evaluates for a pod that is already running.

The submodule started the controller before its identity was complete:

- `helm_release.aws-load-balancer-controller` referenced the IAM role ARN through the service
  account annotation, so Terraform ordered it after `aws_iam_role`. It had no edge at all to
  `aws_iam_role_policy_attachment`, so the attachment was created **in parallel** with the Helm
  install. The first controller pod could therefore call ELB APIs against a role that carried no
  policy yet.
- `aws_eks_pod_identity_association` carried `depends_on = [helm_release...]`, the reverse of the
  required order. In `pod_identity_association` mode the pods were guaranteed to start before the
  association existed, so they never received credentials at all.

Once an Ingress reconcile fails, controller-runtime's exponential backoff pushes the retry
interval toward its ceiling, so the Ingress keeps showing a stale `AccessDenied` condition long
after IAM is correct. That is why the failure looks permanent and why a pod restart appears to
be the fix.

The `external-secrets` submodule already solved the same class of problem (specified in
`specs/007-external-secrets-pod-identity`). This change brings the load balancer controller in
line with that pattern.

## User Scenarios & Testing

### User Story 1 - Fresh Install Needs No Manual Restart (Priority: P1)

As a platform engineer installing the module on a new cluster, the first Ingress I create is
attached to an ALB without me restarting the controller.

**Why this priority**: This is the reported defect. The workaround requires cluster access and
knowledge that the restart is what fixes it, which turns every new cluster into a manual step.

**Independent Test**: Apply the module against a cluster with no prior controller install, create
an Ingress, and confirm the ALB is provisioned without touching the controller pods.

**Acceptance Scenarios**:

1. **Given** a fresh apply, **When** the controller pod starts, **Then** the IAM role, its policy
   attachment and, where applicable, the Pod Identity association already exist.
2. **Given** a fresh apply, **When** an Ingress is created, **Then** it is reconciled and attached
   to an ALB with no `AccessDenied` condition and no manual pod restart.

### User Story 2 - Pod Identity Mode Delivers Credentials (Priority: P1)

As a platform engineer selecting `iam.attachment_method = "pod_identity_association"`, the
controller runs with credentials from the first pod onwards.

**Why this priority**: In this mode the previous ordering guaranteed failure rather than merely
racing. Pod Identity injects credentials at admission, so a pod admitted before the association
exists has no credentials at all for its whole lifetime.

**Independent Test**: Apply with `attachment_method = "pod_identity_association"` on a fresh
cluster and confirm the controller authenticates without a restart.

**Acceptance Scenarios**:

1. **Given** Pod Identity mode, **When** the module applies, **Then** the association is created
   before the Helm release, not after it.

### User Story 3 - Identity Changes Reach Running Pods (Priority: P2)

As an operator changing the controller's identity on an existing cluster, the running pods pick
up the change instead of silently keeping stale credentials.

**Why this priority**: Ordering only protects the first start. A later identity change - switching
attachment method, replacing the role - leaves already-running pods on their old credentials, and
nothing in Terraform or Kubernetes restarts them.

**Independent Test**: Change the identity wiring on an existing cluster and confirm the
controller deployment rolls as part of the apply.

**Acceptance Scenarios**:

1. **Given** a change to the role or its policy attachment, **When** the module applies, **Then**
   the controller pod template changes and the deployment is rolled.
2. **Given** no identity change, **When** the module applies again, **Then** the pod template is
   unchanged and no needless rollout occurs.

### Edge Cases

- IAM and STS are eventually consistent: correct resource ordering does not guarantee the policy
  is effective on the data plane the instant the create call returns.
- `attachment_method = null` leaves the association to the caller; the module cannot order
  something it does not create, and the caller carries that responsibility.
- Consumers who set `podAnnotations` through `configs` must keep their annotations; Helm merges
  layered values maps, so module and consumer keys must coexist.
- Existing installs pick up a pod template change on upgrade and therefore roll once. This is
  acceptable and in fact remediates any currently stuck controller.

## Requirements

### Functional Requirements

- **FR-001**: The IAM role, its policy attachment, and the Pod Identity association (when this
  module creates it) MUST all exist before the Helm release is installed.
- **FR-002**: The Pod Identity association MUST NOT depend on the Helm release.
- **FR-003**: The module MUST wait a bounded, configurable interval between completing the
  identity wiring and installing the chart, to absorb IAM/STS eventual consistency.
- **FR-004**: That wait MUST be skippable by configuration and MUST NOT recur on applies where
  the identity is unchanged.
- **FR-005**: A change to the controller's identity MUST change the controller pod template so
  the deployment rolls and replacement pods receive current credentials.
- **FR-006**: An apply with no identity change MUST NOT change the pod template.
- **FR-007**: The new input MUST be exposed through the root module's
  `alb_load_balancer_controller.iam` object and MUST be optional with a working default.
- **FR-008**: The new input MUST reject values that are not valid duration strings.

### Non-Functional Requirements

- **NFR-001**: No existing input, output, or resource address may be removed or renamed; the
  change must be a drop-in upgrade.
- **NFR-002**: Any new provider requirement MUST be declared with a pessimistic constraint in the
  submodule that uses it.
- **NFR-003**: The behaviour and its rationale MUST be documented in the submodule header and the
  root upgrade guide, since the fix is invisible in the resource list.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A fresh install reconciles its first Ingress to an ALB with no manual pod restart.
- **SC-002**: The dependency graph shows the Helm release ordered after the policy attachment and
  the Pod Identity association, in all three attachment modes.
- **SC-003**: A second apply with no identity change plans no controller changes.
- **SC-004**: Terraform formatting, validation and documentation generation pass.
- **SC-005**: No existing consumer configuration breaks; every previously valid input still works
  with unchanged meaning.

## Assumptions

- Consumers on `pod_identity_association` have the EKS Pod Identity Agent installed; the module
  adds it through `default_addons` as part of the External Secrets work and it is not re-specified
  here.
- The chart exposes a top-level `podAnnotations` value that reaches the controller's pod template.
- A bounded wait in the low tens of seconds is an acceptable one-time cost on a fresh install, and
  consumers who disagree can set it to zero.
- The next released version is `2.30.0`; the upgrade guide entry is written against that number.
