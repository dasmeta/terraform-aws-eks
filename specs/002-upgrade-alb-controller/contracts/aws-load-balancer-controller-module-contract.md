# Contract: AWS Load Balancer Controller Module

## Purpose

Define the supported behavior of the repository's AWS load balancer controller wrapper
after the `v3.3.0` upgrade.

## Consumer Contract

### Root module compatibility

- Existing consumers of `alb_load_balancer_controller` must remain valid without adding
  new required inputs.
- Compatibility-sensitive legacy ALB log fields may remain accepted even if the dead
  implementation behind them is removed.

### Release source behavior

- The module supports the default upstream repository/chart path.
- The module supports a custom repository plus chart name.
- The module supports a direct packaged-chart endpoint.
- When a direct packaged-chart endpoint is supplied, it is authoritative and any
  repository value is ignored.

### Image override behavior

- Operators may override controller image repository, image tag, or both.
- Omitted image override fields fall back to the chart's default behavior.

### Identity binding behavior

- The module supports service-account role annotation attachment.
- The module supports built-in Pod Identity association attachment.
- The module supports creating the IAM role and policy with no built-in attachment mode
  for externally managed Pod Identity association.
- Simultaneous built-in service-account annotation and built-in Pod Identity attachment is
  invalid and must fail validation.

### Policy artifact behavior

- The module consumes a checked-in IAM policy JSON file stored under
  `modules/aws-load-balancer-controller/`.
- The policy file must be refreshed from the upstream tagged policy path that matches the
  intended controller release baseline.

### Example contract

- The repository includes `examples/eks-with-alb-controller`.
- The example uses service-account annotation by default.
- The example keeps unrelated optional components disabled.
- The example demonstrates controller-managed ingress behavior for the `http-echo`
  workload.
