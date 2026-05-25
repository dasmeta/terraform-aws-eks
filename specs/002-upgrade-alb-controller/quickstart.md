# Quickstart: Upgrade ALB Controller

## Goal

Validate the upgraded AWS load balancer controller module, its refreshed IAM policy, and
the new dedicated example before merging.

## 1. Refresh the policy artifact

Update `modules/aws-load-balancer-controller/iam-policy.json` from the upstream tagged
controller policy source for `v3.3.0`, then verify the checked-in file matches the
intended release baseline referenced in module documentation.

## 2. Implement and sync the wrapper changes

Apply the module changes in:

- `modules/aws-load-balancer-controller/`
- root wrapper files such as `alb-ingress-controller.tf`, `variables.tf`, and `README.md`
- `examples/eks-with-alb-controller/`

Keep the root wrapper backward-compatible and ensure dead ALB log implementation is
removed without reintroducing unsupported behavior.

## 3. Run local verification

Run at least:

```bash
terraform fmt -recursive
terraform validate
```

If repository-specific docs automation is available, refresh Terraform docs for the
changed module and example so generated tables stay aligned.

## 4. Validate the dedicated example

Use the new `examples/eks-with-alb-controller` scenario as the primary validation path.
The example should:

- disable unrelated optional platform components
- deploy the controller with the default service-account annotation path
- deploy the `http-echo` sample workload
- demonstrate controller-managed ingress behavior for that workload

## 5. Confirm the operator-facing docs

Review `modules/aws-load-balancer-controller/README.md` to ensure it documents:

- what the controller manages
- the architecture sketch
- the three identity states
- chart source and image override behavior
- the future upgrade workflow for chart version discovery and policy refresh

## 6. Record verification limitations

If any example apply, AWS dependency, or documentation automation step cannot run locally,
record that limitation and its risk in the implementation summary rather than claiming the
feature is fully validated.
