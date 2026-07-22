# Data Model: Upgrade AWS Load Balancer Controller Chart Version

## Entity: Chart Version Baseline
- **Description**: The default Helm chart version for the controller and, by extension, the controller image via the chart `appVersion`.
- **Fields**:
  - `chart.version`: default chart version (`3.4.2`)
  - `chart.repository`: chart repository (`https://aws.github.io/eks-charts`, unchanged)
  - `chart.name`: chart name or direct `.tgz` URL (`aws-load-balancer-controller`, unchanged)
- **Validation rules**:
  - Must reference a published, stable chart version.
  - Consumers who set `chart.version` override the default.
  - Backward-compatible for consumers who do not pin the version.
- **Relationships**:
  - Determines the controller image when `image.tag` is unset.

## Entity: Controller Image Override
- **Description**: Optional explicit controller image, off by default.
- **Fields**:
  - `image.repository`: image repository (null by default)
  - `image.tag`: image tag (null by default -> chart default image used)
- **Validation rules**:
  - When null, the chart default image (matching the chart `appVersion`) is used.

## Entity: IAM Policy Contract
- **Description**: The vendored permission set attached to the controller's IAM role, which must match the upstream controller policy for the deployed version.
- **Fields**:
  - `iam-policy.json`: vendored policy document
- **Validation rules**:
  - MUST be equivalent to the upstream controller `iam_policy.json` for the target version.
  - Updated only when the upstream policy for the target version differs from the vendored copy.
- **State transitions**:
  1. Identify the target controller version (from the chart `appVersion`).
  2. Compare vendored policy to the upstream policy for that version.
  3. If a delta exists, refresh the vendored policy; otherwise leave unchanged.
