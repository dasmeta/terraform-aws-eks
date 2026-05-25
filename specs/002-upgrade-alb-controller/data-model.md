# Data Model: Upgrade ALB Controller

## Entity: Controller Release Source

- **Purpose**: Defines where the Helm release is retrieved from.
- **Fields**:
  - `version`: desired controller chart version
  - `repository`: repository URL for repository-based chart resolution
  - `chart`: chart name or direct packaged-chart endpoint
  - `source_mode`: derived mode with values `repository_chart` or `direct_package`
- **Validation Rules**:
  - `version` remains required for supported release selection.
  - `source_mode=direct_package` when `chart` is a direct packaged-chart endpoint.
  - When `source_mode=direct_package`, `repository` is ignored.
- **Relationships**:
  - Drives the Helm release configuration.
  - Is documented in the module README maintenance guide.

## Entity: Controller Image Override

- **Purpose**: Allows mirrored or custom controller image selection without changing the
  broader chart source behavior.
- **Fields**:
  - `repository`: optional image repository override
  - `tag`: optional image tag override
- **Validation Rules**:
  - Omitted values fall back to chart defaults.
  - Partial override is allowed if the chart supports it and the resulting image reference
    remains valid.
- **Relationships**:
  - Applied through controller Helm values.
  - Independent from the chart source selection.

## Entity: Identity Binding Mode

- **Purpose**: Describes how the controller workload obtains AWS permissions.
- **Fields**:
  - `mode`: one of `service_account_annotation`, `pod_identity_association`,
    `external_association`
  - `service_account_name`: Kubernetes service account bound to the controller
  - `role_name`: IAM role created for controller permissions
- **Validation Rules**:
  - Exactly one effective mode is allowed at a time.
  - `external_association` means the module creates IAM artifacts but does not attach them
    through either built-in mechanism.
  - Simultaneous built-in service-account annotation and built-in Pod Identity attachment
    is invalid.
- **Relationships**:
  - Depends on the `Controller Policy Artifact`.
  - Influences IAM, Helm, and documentation behavior.

## Entity: Controller Policy Artifact

- **Purpose**: Repository-managed copy of the IAM permissions required by the targeted
  controller release.
- **Fields**:
  - `source_tag`: upstream controller tag from which the policy was copied
  - `source_path`: upstream tagged policy path
  - `local_path`: repository path for the checked-in policy JSON
- **Validation Rules**:
  - `local_path` must be committed in the module directory.
  - `source_tag` must align with the intended controller release baseline.
- **Relationships**:
  - Consumed by the IAM role/policy resources.
  - Documented in the upgrade maintenance procedure.

## Entity: Root Wrapper Configuration

- **Purpose**: Preserves the main module's supported consumer interface while exposing a
  narrow set of new optional controls.
- **Fields**:
  - existing compatibility fields already accepted by `alb_load_balancer_controller`
  - new optional release-source controls
  - new optional image override controls
  - new optional identity-mode controls
  - deprecated ALB log compatibility fields retained only as compatibility-sensitive inputs
- **Validation Rules**:
  - Existing supported callers must not need new required fields.
  - Deprecated compatibility fields must not reactivate removed dead implementation paths.
- **Relationships**:
  - Mapped into the child module.
  - Reflected in root README inputs and example usage.

## Entity: Dedicated Example Scenario

- **Purpose**: Provides a minimal working scenario for validating and demonstrating the
  module.
- **Fields**:
  - `example_name`: `eks-with-alb-controller`
  - `default_identity_mode`: `service_account_annotation`
  - `sample_workload`: `http-echo`
  - `optional_components`: disabled-by-default extras outside the scenario's minimal scope
- **Validation Rules**:
  - The example must be self-contained for the default validation path.
  - It must demonstrate controller-managed ingress behavior.
- **Relationships**:
  - Depends on the root wrapper configuration.
  - Supports quickstart validation and documentation.
