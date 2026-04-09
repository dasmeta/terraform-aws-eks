# Feature Specification: Karpenter System Isolation

**Feature Branch**: `001-karpenter-system-isolation`  
**Created**: 2026-04-08  
**Status**: Draft  
**Input**: User description: "for dasmeta/terraform-aws-eks Assign karpenter highest prio(we have predefined priority classes comming from priority-class submodule) and have multiple replicas(2 one by default) for karpenter(seems this is already in place), prevent anything non important get into system node, the one we create for carpenter and we have example how this can be done here dasmeta/terraform-aws-eks/examples/eks-with-karpenter/1-example.tf"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Protect System Node Capacity (Priority: P1)

As a platform engineer, I want only critical system workloads and Karpenter controller
components to run on dedicated system nodes so business workloads cannot crowd out core
cluster management capacity.

**Why this priority**: System node protection is required for cluster stability and is the
highest operational risk if not enforced.

**Independent Test**: Deploy one non-critical workload without explicit system-node
toleration and confirm it does not schedule to system nodes, while critical components
continue to schedule successfully.

**Acceptance Scenarios**:

1. **Given** dedicated system nodes exist, **When** a non-critical workload is deployed
   without required system-node toleration/selectors, **Then** it is not scheduled on
   system nodes.
2. **Given** dedicated system nodes exist, **When** cluster-critical components are
   deployed, **Then** they can schedule on system nodes without manual intervention.
3. **Given** scheduling restrictions are enabled, **When** Karpenter provisions worker
   capacity, **Then** non-critical workloads are placed on general worker nodes.

---

### User Story 2 - Highest Priority for Karpenter Pods (Priority: P2)

As a platform engineer, I want Karpenter pods to use the highest available predefined
priority class so scaling and node lifecycle operations are not preempted by lower
importance workloads.

**Why this priority**: Karpenter responsiveness directly affects workload availability
under scale events and disruptions.

**Independent Test**: Inspect deployed Karpenter pods and verify they are bound to the
highest predefined priority class from the priority-class submodule.

**Acceptance Scenarios**:

1. **Given** predefined priority classes are present, **When** Karpenter components are
   deployed, **Then** they use the highest priority class configured for system-critical
   scheduling.
2. **Given** competing lower-priority workloads, **When** the cluster is resource
   constrained, **Then** Karpenter components remain schedulable.

---

### User Story 3 - Reliable Multi-Replica Karpenter Baseline (Priority: P3)

As a platform engineer, I want Karpenter to run with a multi-replica baseline (default 2)
so control-plane-adjacent autoscaling behavior remains available during single-pod failures.

**Why this priority**: Replica resilience improves operational continuity but depends on
the scheduling isolation established in higher-priority stories.

**Independent Test**: Verify the effective replica count is at least two by default and
that one replica can fail without loss of autoscaling control functionality.

**Acceptance Scenarios**:

1. **Given** default module settings, **When** Karpenter is enabled, **Then** at least two
   Karpenter controller replicas are scheduled.
2. **Given** one Karpenter replica becomes unavailable, **When** autoscaling events occur,
   **Then** cluster autoscaling control remains functional.

---

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when the highest predefined priority class is missing or renamed?
- How does the system behave when system nodes are fully saturated by critical workloads?
- What happens if users add tolerations that could bypass intended non-critical workload
  isolation policies?
- How does the system handle single-AZ or small clusters where two replicas cannot be
  placed with ideal spread constraints?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: The module MUST enforce scheduling boundaries so non-critical workloads are
  excluded from dedicated system nodes by default.
- **FR-002**: The module MUST allow critical system workloads (including Karpenter) to
  schedule on dedicated system nodes without requiring per-workload manual overrides.
- **FR-003**: Karpenter workloads MUST use the highest predefined priority class available
  from the module's priority class set.
- **FR-004**: Karpenter MUST run with a default replica count of at least two.
- **FR-005**: Users MUST be able to retain or increase Karpenter replica count through
  module configuration without breaking default system-node isolation behavior.
- **FR-006**: The module MUST provide clear behavior for capacity pressure on system nodes,
  including deterministic scheduling outcomes for non-critical workloads.
- **FR-007**: Module examples and usage documentation MUST include at least one scenario
  demonstrating system-node isolation and Karpenter priority behavior.
- **FR-008**: Validation outputs MUST make it possible to confirm effective Karpenter
  priority class and replica baseline after deployment.

### Key Entities *(include if feature involves data)*

- **System Node Pool**: A dedicated node group for system-critical components with
  scheduling restrictions that exclude non-critical workloads.
- **Workload Criticality Class**: Classification of workloads into system-critical versus
  non-critical, used to determine scheduling eligibility on system nodes.
- **Priority Class Profile**: Predefined set of workload priorities where Karpenter maps
  to the highest level.
- **Karpenter Availability Profile**: Desired Karpenter controller replica baseline and
  associated resilience expectations.

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: In validation runs, 100% of non-critical test workloads without explicit
  system-node permissions are scheduled outside system nodes.
- **SC-002**: In validation runs, 100% of Karpenter controller pods are assigned the
  highest predefined priority class.
- **SC-003**: In default deployments, at least 2 Karpenter replicas are running and
  healthy within 10 minutes of control component rollout completion.
- **SC-004**: During a simulated single Karpenter-pod failure, autoscaling control remains
  available without manual remediation.

## Assumptions

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right assumptions based on reasonable defaults
  chosen when the feature description did not specify certain details.
-->

- Existing predefined priority classes from the priority-class submodule are available and
  can be referenced by Karpenter workloads.
- A dedicated system node model already exists or is considered valid for this repository's
  EKS usage patterns.
- The current behavior that supports multiple Karpenter replicas is retained; this feature
  formalizes and validates the default baseline.
- The example at `examples/eks-with-karpenter/1-example.tf` is the reference behavior for
  system-node isolation expectations and will remain aligned with module behavior.
