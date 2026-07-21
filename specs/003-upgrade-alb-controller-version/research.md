# Research: Upgrade AWS Load Balancer Controller Chart Version

## Decision 1: Target chart version 3.4.2
- **Decision**: Set the module default `chart.version` to `3.4.2`.
- **Rationale**: `3.4.2` is the latest stable `aws-load-balancer-controller` chart on `eks-charts`.
- **Alternatives considered**:
  - Stay on `3.3.0`: rejected — does not satisfy the upgrade and misses fixes.
  - `3.4.0` / `3.4.1`: rejected — superseded by `3.4.2`.

## Decision 2: Let the controller image follow the chart
- **Decision**: Keep `image.tag` defaulting to null so the chart's default image (its `appVersion`, `v3.4.2`) is used.
- **Rationale**: Since chart major `3.x` the chart version aligns with the controller version, so the image tracks the chart automatically; a separate image pin would only add drift risk.
- **Alternatives considered**:
  - Pin `image.tag` explicitly: rejected — redundant and easy to desync from the chart.

## Decision 3: Verify IAM policy parity (no change needed)
- **Decision**: Keep the vendored `iam-policy.json` unchanged after confirming it matches the upstream controller policy for the target version.
- **Rationale**: The most common ALB-controller upgrade break is a change in required IAM permissions. The upstream controller IAM policy was compared between the previous and target versions and found identical, and the vendored policy matches both — so no permission delta exists for this bump.
- **Verification**: Normalized comparison of the upstream controller `iam_policy.json` for the previous vs target version (identical) and of the vendored policy against the target version (equivalent).
- **Alternatives considered**:
  - Blindly refresh the vendored policy: rejected — unnecessary churn when there is no delta.
  - Skip the IAM check: rejected — this is the highest-risk aspect of the upgrade and must be verified.

## Decision 4: Validation strategy
- **Decision**: Validate via `terraform validate` for the module and `examples/basic`, plus the IAM-policy equivalence check.
- **Rationale**: A full functional test of the controller requires a real EKS cluster with AWS integration (the controller reconciles actual load balancers); static validation plus IAM parity is the appropriate module-level gate. Downstream consumers exercise the runtime behavior on real clusters.
- **Alternatives considered**:
  - Local non-cloud cluster apply: rejected — the controller cannot manage AWS load balancers without AWS integration, so a local apply would not exercise its real behavior.
