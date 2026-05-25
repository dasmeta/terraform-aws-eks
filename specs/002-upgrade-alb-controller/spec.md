# Feature Specification: Upgrade ALB Controller

**Feature Branch**: `[002-upgrade-alb-controller]`  
**Created**: 2026-05-19  
**Status**: Draft  
**Input**: User description: "Upgrade the `modules/aws-load-balancer-controller` submodule to the latest upstream controller chart and policy, remove dead code, support customizable chart and image sources, support both IAM role annotation and EKS Pod Identity attachment patterns, preserve existing parent-module usage, add a dedicated example with http-echo, and improve module documentation including version-management guidance."

## Clarifications

### Session 2026-05-19

- Q: When both attachment modes or neither attachment mode are selected, what behavior should the module support? → A: Allow neither attachment mode and support manual external Pod Identity association; do not require the module to attach the role itself.
- Q: When a direct packaged-chart endpoint and a repository value are both provided, which source should win? → A: The direct packaged-chart endpoint takes precedence and the repository value is ignored.
- Q: Which attachment mode should the dedicated example use by default? → A: The dedicated example should use the service-account role annotation path by default.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upgrade Controller Safely (Priority: P1)

A platform engineer upgrades or deploys the AWS load balancer controller module and gets the current supported upstream controller behavior without having to change existing root-module usage patterns.

**Why this priority**: The primary value is keeping controller installation current while avoiding regressions for clusters that already consume the main EKS module.

**Independent Test**: Can be fully tested by applying the module through the main EKS module with existing ALB-controller settings and confirming the controller role, service account integration, and controller deployment are created successfully without new required inputs.

**Acceptance Scenarios**:

1. **Given** a cluster configuration that already enables the load balancer controller through the main EKS module, **When** the upgraded module is applied, **Then** the controller is installed successfully and existing caller inputs remain valid.
2. **Given** the module is installed for a new cluster, **When** the controller policy and release assets are rendered, **Then** they reflect the intended upstream controller release and its matching permission set.

---

### User Story 2 - Choose Runtime Integration Method (Priority: P2)

A platform engineer can connect the controller workload to AWS permissions using either the existing service-account role annotation pattern or an EKS Pod Identity association pattern, depending on the cluster standard in use.

**Why this priority**: Clusters are moving toward Pod Identity, but existing clusters still depend on the older service-account annotation path. Supporting both avoids forced migrations and fragmented module behavior.

**Independent Test**: Can be fully tested by configuring the module once with service-account role attachment and once with Pod Identity association, then confirming each mode produces the expected permission linkage without requiring the other mode.

**Acceptance Scenarios**:

1. **Given** a cluster that uses service-account role annotations, **When** the module is configured with the legacy attachment mode, **Then** the controller service account is linked to the IAM role through its explicit annotation.
2. **Given** a cluster that uses EKS Pod Identity associations, **When** the module is configured with Pod Identity mode, **Then** the controller service account is linked to the IAM role through a Pod Identity association and does not require the legacy annotation to function.
3. **Given** a platform team manages Pod Identity associations outside this module, **When** the module is configured with neither attachment mode enabled, **Then** it still creates the IAM role and policy needed for manual external association.
4. **Given** a platform team standardizes on one attachment mode, **When** the module documentation is consulted, **Then** the required inputs and expected behavior for that mode are clear and testable.

---

### User Story 3 - Reuse Module Across Distribution Sources (Priority: P3)

A platform engineer can source the controller release from the default upstream chart location, from a custom repository, or from a direct packaged-chart URL, and can also override the controller image source when required by mirroring or restricted-network policies.

**Why this priority**: Enterprises often mirror charts and images or consume packaged chart files directly, so the module must support those delivery patterns without local patching.

**Independent Test**: Can be fully tested by rendering the controller configuration three ways: default source, custom repository plus chart name, and direct packaged-chart endpoint, while separately overriding image repository and image tag.

**Acceptance Scenarios**:

1. **Given** a standard deployment, **When** no custom chart source is provided, **Then** the module uses its default supported upstream chart source and version.
2. **Given** an organization-hosted chart repository, **When** custom repository and chart values are provided, **Then** the module uses those values without changing other calling patterns.
3. **Given** a direct packaged-chart endpoint, **When** that endpoint is provided as the chart source, **Then** the module installs the controller from that endpoint and ignores any repository value that may also be set.
4. **Given** an organization-hosted container registry mirror, **When** custom controller image repository or tag values are provided, **Then** the controller deployment uses the requested image source.

---

### User Story 4 - Validate With a Minimal Example (Priority: P4)

A platform engineer can use a dedicated example to validate the module end to end with minimal dependencies, using the existing service-account role annotation path by default.

**Why this priority**: The example is primarily a validation and maintenance aid, so it should favor the most self-contained path and avoid requiring separate external identity setup.

**Independent Test**: Can be fully tested by applying the example, confirming the controller deploys with the default attachment mode, and verifying the sample application is exposed through controller-managed ingress behavior.

**Acceptance Scenarios**:

1. **Given** the dedicated `eks-with-alb-controller` example, **When** it is applied without extra identity wiring outside the example, **Then** it uses the service-account role annotation path by default.
2. **Given** the example has unrelated optional platform components disabled, **When** it is applied, **Then** it still demonstrates controller-managed ingress behavior for the sample application.

### Edge Cases

- What happens when both attachment modes are configured at once? The module must define a single predictable precedence or fail with a clear validation error, while still allowing neither mode when external attachment is managed manually.
- What happens when a direct packaged-chart endpoint is used together with a repository value? The module must ignore the repository value and document that the direct chart source is authoritative.
- How does the module behave when the controller policy source is updated upstream but the local policy file is not refreshed? The documentation must make drift detection and update steps explicit.
- How does the example behave when optional platform components are disabled? The example must still demonstrate controller-driven ingress behavior successfully with only the minimal dependencies enabled.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The module MUST install the AWS load balancer controller using the upstream release targeted by this feature and include the matching permission policy content required by that release.
- **FR-002**: The module MUST preserve backward-compatible usage through the repository's main EKS module so that current callers are not required to change existing load balancer controller inputs.
- **FR-003**: The module MUST continue to support linking the controller service account to its IAM role through an explicit service-account role annotation.
- **FR-004**: The module MUST support linking the controller service account to its IAM role through an EKS Pod Identity association.
- **FR-004a**: The module MUST support creating the IAM role and policy without attaching them through either built-in mode so that operators can create and manage the Pod Identity association separately.
- **FR-005**: The module MUST let operators choose the controller release source through defaults, a custom repository plus chart name, or a direct packaged-chart endpoint.
- **FR-005a**: When a direct packaged-chart endpoint is provided, the module MUST treat it as the authoritative chart source and ignore any repository value supplied alongside it.
- **FR-006**: The module MUST let operators override the controller image repository and image tag independently of the default release source.
- **FR-007**: The module MUST remove dead, commented, or non-usable code paths from the load balancer controller module, including the unused nested ALB log helper subdirectory, while leaving the active behavior intact.
- **FR-008**: The module MUST refresh its module documentation so users can understand what the controller manages, how it connects Kubernetes ingress or gateway-style resources to AWS load balancers, and how IAM permissions are attached to the controller workload.
- **FR-009**: The module documentation MUST include a simple architecture sketch that shows the relationship among cluster workloads, ingress resources, the controller, AWS load balancers, the IAM role, and the controller service account.
- **FR-010**: The module documentation MUST describe a repeatable maintenance procedure for future upgrades, including where to discover newer controller releases, where to retrieve the matching permission policy, and where that policy must be stored in the repository.
- **FR-011**: The repository MUST include a dedicated example for this module under `examples/eks-with-alb-controller` that demonstrates controller behavior with a test `http-echo` application and keeps unrelated optional platform components disabled.
- **FR-011a**: The dedicated example MUST use the service-account role annotation attachment path by default so it can be applied and validated without requiring separate external Pod Identity setup.
- **FR-012**: The example MUST demonstrate that the controller can reconcile ingress-facing traffic for the sample application using the module as documented.
- **FR-013**: The module and example documentation MUST clearly identify any remaining manual decisions operators need to make when selecting attachment mode, chart source, or image source.

### Key Entities *(include if feature involves data)*

- **Controller Release Source**: The selected source for the controller deployment assets, including default upstream location, custom repository and chart selection, or a direct packaged-chart endpoint.
- **Permission Attachment Mode**: The mechanism used to give the controller AWS permissions, either through service-account role annotation or EKS Pod Identity association.
- **External Permission Attachment**: An operator-managed pattern where the module creates the IAM role and policy, but the final workload-to-role association is created outside the module.
- **Controller Policy Artifact**: The local repository copy of the permission policy that must stay aligned with the targeted upstream controller release.
- **Reference Example**: The dedicated example configuration that demonstrates minimal working controller behavior for future validation and documentation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Existing root-module consumers can adopt the upgraded module without introducing any new required load balancer controller inputs.
- **SC-002**: A maintainer can identify the next controller upgrade source locations and local policy-file destination in under 10 minutes using only the module documentation.
- **SC-003**: A new dedicated example can be applied and reviewed to demonstrate controller-managed ingress behavior for a sample application with unrelated optional components disabled.
- **SC-003a**: The dedicated example can be validated end to end without requiring any identity association to be created outside the example.
- **SC-004**: Both supported permission attachment modes have documented setup steps and acceptance checks that allow an operator to determine whether the chosen mode is configured correctly.
- **SC-004a**: Operators who manage Pod Identity associations outside the module can still use the module to produce the required IAM role and policy artifacts without any built-in attachment mode enabled.
- **SC-005**: Dead code and unused submodule content are removed from the load balancer controller module so that no inactive commented feature path remains as part of the supported implementation.

## Assumptions

- Existing consumers of the main EKS module rely on the current `alb_load_balancer_controller` object shape and should keep working without new mandatory fields.
- The repository will continue to manage a checked-in copy of the controller IAM policy rather than fetching it dynamically during apply time.
- The dedicated example is intended to validate controller behavior with a minimal cluster footprint, not to showcase every optional platform component in the repository.
- The controller continues to be a shared cluster capability that other ingress, gateway, or load-balanced workloads may depend on.
