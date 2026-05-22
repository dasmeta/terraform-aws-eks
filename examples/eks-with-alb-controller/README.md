# eks-with-alb-controller

This example creates a minimal EKS cluster with the AWS Load Balancer Controller enabled,
deploys the `http-echo` sample application from `dasmeta/base`, and exposes it with an
ALB-backed Kubernetes `Ingress`.

## What this example keeps enabled

- EKS cluster
- AWS Load Balancer Controller
- One sample `http-echo` workload with an `alb` ingress

## What this example disables

- external-dns
- cert-manager
- fluent-bit
- external-secrets
- node-problem-detector
- autoscaling helpers
- karpenter
- keda
- linkerd
- kyverno

## Identity mode used by default

This example uses the service-account annotation path by default:

- `iam.attachment_method = "service_account_role_annotation"`

That keeps the example self-contained and avoids requiring separate Pod Identity setup to
validate the controller.

## Validation idea

1. Apply the example.
2. Wait for the `http-echo` Helm release and the ALB controller deployment to become ready.
3. Inspect the created `Ingress` in the `default` namespace.
4. Confirm the AWS Load Balancer Controller creates the corresponding AWS load balancer.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.http_echo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpcs.ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
