# Feature Specification: EKS 1.34 Module Support

**Feature Branch**: `004-eks-134-support`  
**Created**: 2026-07-20  
**Status**: Draft  
**Input**: User description: "DMVP-10175: Support EKS 1.34 in dasmeta/terraform-aws-eks, set 1.34 as the default EKS version, review Kubernetes/EKS deprecated or removed APIs, upgrade compatible Terraform modules/addons/Helm charts, add migration/changelog notes in main.tf for terraform-docs README generation, preserve existing public module compatibility, and keep live cluster upgrades out of scope."

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

### User Story 1 - Consume EKS 1.34 By Default (Priority: P1)

A platform engineer can use the reusable AWS EKS module without setting an explicit cluster version and receive an EKS 1.34-ready module configuration by default.

**Why this priority**: This is the core value of the ticket: downstream module consumers should inherit the new supported default before separate environment upgrade tickets consume the module release.

**Independent Test**: Review the module interface and generated documentation to confirm all default EKS version surfaces now resolve to 1.34 while existing callers can still override the version explicitly.

**Acceptance Scenarios**:

1. **Given** a consumer uses the root module without specifying an EKS version, **When** the module inputs are evaluated, **Then** the documented default EKS version is 1.34.
2. **Given** a consumer explicitly sets an older supported version, **When** the module inputs are evaluated, **Then** the override path remains available unless a separate approved breaking change removes it.

---

### User Story 2 - Verify Upgrade Compatibility (Priority: P2)

A module maintainer can verify that Kubernetes/EKS 1.34 compatibility was checked across module defaults, addons, Helm chart integrations, and examples before release.

**Why this priority**: A default version upgrade can expose deprecated or removed APIs and incompatible addon or chart versions. Compatibility evidence reduces downstream upgrade risk.

**Independent Test**: Inspect the compatibility evidence and repository changes to confirm each relevant module-managed component is either updated for EKS 1.34 or documented as already compatible.

**Acceptance Scenarios**:

1. **Given** an EKS 1.34 compatibility review is complete, **When** a reviewer checks the evidence, **Then** Kubernetes/EKS deprecations and removals relevant to this module are addressed or explicitly marked not applicable.
2. **Given** a module-managed addon or Helm chart has an EKS 1.34 compatibility concern, **When** the change is prepared, **Then** that component is upgraded or the remaining risk is documented before release.

---

### User Story 3 - Follow Documented Migration Guidance (Priority: P3)

A platform engineer planning a later client or environment upgrade can read the module documentation and understand the reusable-module migration notes, validation expectations, and boundaries for live cluster delivery.

**Why this priority**: The module change must be reusable and reviewable before environment-specific upgrade tickets begin.

**Independent Test**: Review generated documentation to confirm the migration/changelog notes are present, visible, and clear about live cluster upgrades being out of scope.

**Acceptance Scenarios**:

1. **Given** the module documentation is regenerated, **When** a reader reviews the EKS 1.34 migration notes, **Then** they can identify the version default change and the required follow-up delivery scope for real clusters.
2. **Given** this ticket is complete, **When** downstream teams plan client cluster upgrades, **Then** they can create separate delivery tickets without treating this module ticket as an environment rollout.

---

### Edge Cases

- Consumers pinning an explicit older EKS version must not be forced to 1.34 by the default change alone.
- Existing examples or submodules with their own EKS version defaults must not drift from the root module default.
- Module-managed charts or addons without a clear EKS 1.34 compatibility statement must be handled conservatively and documented.
- The change must not imply that live clusters are upgraded by publishing the module.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The module MUST use EKS version 1.34 as the default version for new root-module consumers.
- **FR-002**: Affected submodules and examples MUST use EKS version 1.34 as their default where they expose an EKS version default.
- **FR-003**: Existing consumers MUST retain the ability to set a supported explicit EKS version unless a breaking change is separately proposed and approved.
- **FR-004**: The implementation MUST review Kubernetes and EKS 1.34 deprecations, removals, and behavior changes that could affect resources, manifests, addons, or Helm charts managed by this repository.
- **FR-005**: Module-managed Terraform modules, EKS addons, and Helm charts MUST be upgraded when required for EKS 1.34 compatibility.
- **FR-006**: Compatibility decisions MUST be documented with enough evidence for reviewers to distinguish addressed items from not-applicable items.
- **FR-007**: The module migration/changelog notes MUST describe the EKS 1.34 default change and any operator-visible migration considerations.
- **FR-008**: Generated README documentation MUST reflect the updated defaults and migration/changelog notes.
- **FR-009**: The change MUST remain scoped to reusable module development and MUST NOT apply changes to live clusters or real environments.
- **FR-010**: The repository MUST include Speckit evidence for the module-impacting change before module source changes are applied.

### Key Entities

- **EKS Module Release**: The reusable module state that downstream consumers reference, including default EKS version, addon compatibility, generated documentation, and migration notes.
- **Compatibility Finding**: A reviewed Kubernetes/EKS 1.34 deprecation, removal, addon constraint, chart constraint, or not-applicable decision with evidence.
- **Module Consumer**: A downstream user or repository that consumes the module and may rely on either defaults or explicit version overrides.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reviewer can identify 1.34 as the default EKS version in every documented root and affected submodule default location.
- **SC-002**: A reviewer can trace every EKS 1.34 compatibility decision to an explicit repository change or a documented not-applicable finding.
- **SC-003**: A consumer can identify the migration boundary in the generated documentation in under 5 minutes without reading source code.
- **SC-004**: All required validation commands for formatting and documentation sync complete successfully, or any unavailable validation is documented with reason and residual risk.

## Assumptions

- The target repository is `dasmeta/terraform-aws-eks`.
- This is a reusable module development task only; live client or environment cluster upgrades will be handled by separate tickets.
- Compatibility evidence should use official AWS EKS and Kubernetes documentation first, with chart or module upstream release notes used for component-specific decisions.
- The current public wrapper interface should be preserved unless a required incompatibility is found and explicitly approved.
