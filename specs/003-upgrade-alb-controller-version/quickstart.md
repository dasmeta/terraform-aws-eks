# Quickstart: Implement Plan 003

## 1) Confirm workspace state
1. Ensure branch is `003-upgrade-alb-controller-version`.
2. Ensure feature artifacts exist under `specs/003-upgrade-alb-controller-version/`.
3. Baseline default before change: `modules/aws-load-balancer-controller` `chart.version` was `3.3.0`.

## 2) Update the module default
1. Set `chart.version` default to `3.4.2` in `modules/aws-load-balancer-controller/variables.tf`.

## 3) Verify the IAM policy contract
1. Determine the controller version for the target chart (chart `appVersion`).
2. Fetch the upstream controller IAM policy for the previous and target versions:
   - `https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<version>/docs/install/iam_policy.json`
3. Normalize and compare:
   - upstream previous vs upstream target (detect permission delta)
   - vendored `iam-policy.json` vs upstream target (confirm equivalence)
4. If a delta exists, replace `modules/aws-load-balancer-controller/iam-policy.json` with the upstream target policy. If equivalent, leave it unchanged.

## 4) Update docs and example
1. Update the generated input table default in `modules/aws-load-balancer-controller/README.md`.
2. Update the pinned version in `modules/aws-load-balancer-controller/examples/basic/1-example.tf`.

## 5) Validate
1. Format:
   - `terraform fmt -recursive modules/aws-load-balancer-controller`
2. Validate module/example:
   - `cd modules/aws-load-balancer-controller/examples/basic && terraform init -backend=false -input=false && terraform validate`
3. Confirm:
   - default chart version resolves to `3.4.2`
   - vendored IAM policy equals the upstream policy for the target version

## 6) Note on functional testing
- A full functional test (the controller reconciling real AWS load balancers) requires a real EKS cluster with AWS integration and is exercised by downstream consumers; it is out of scope for module-level validation.

## 7) Downstream compatibility summary
- Defaults-only bump; no interface changes. Consumers who pin `chart.version` are unaffected. No migration steps required for normal use.
