# Module Interface Contract

## Scope
This contract covers the version-default change for `modules/aws-load-balancer-controller`. No input or output shape changes are introduced.

## Default delta
- `chart.version`: `3.3.0` -> `3.4.2`.
- `chart.repository`, `chart.name`: unchanged.
- `image.repository`, `image.tag`: unchanged (null by default; controller image follows the chart `appVersion`).

## Compatibility rules
- Consumers who set `chart.version` are unaffected (pins win).
- No new required inputs; no removed inputs; no output changes (`iam_policy_arn` and other outputs unchanged).

## IAM policy contract
- The vendored `iam-policy.json` MUST match the upstream controller policy for the deployed version.
- For this bump, the upstream policy is unchanged between the previous and target versions and the vendored copy already matches, so the policy is unchanged.
- If a future bump introduces an upstream permission delta, the vendored policy MUST be refreshed as part of that change.

## Provider / version constraints
- `versions.tf` is unchanged (no provider constraint impact).

## Cross-cutting
- No breaking changes; no interface widening.
