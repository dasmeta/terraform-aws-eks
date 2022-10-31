<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Example Setup

```tf
module "fluent-bit" {
  source  = "dasmeta/eks/aws//modules/fluent-bit"
  version = "0.1.4"

  cluster_name                = "eks-cluster-name"
  oidc_provider_arn           = "eks_oidc_provider_arn"
  eks_oidc_root_ca_thumbprint = replace("eks_oidc_provider_arn", "/.*id//", "")
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.12.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.12.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.fluent-bit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.fluent-bit](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/2.12.1/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | AWS EKS Cluster name. | `string` | n/a | yes |
| <a name="input_create_log_group"></a> [create\_log\_group](#input\_create\_log\_group) | Wether or no to create log group. | `bool` | `true` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Wether or no to create namespace. | `bool` | `false` | no |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | n/a | `string` | n/a | yes |
| <a name="input_fluent_bit_name"></a> [fluent\_bit\_name](#input\_fluent\_bit\_name) | Container resource name. | `string` | `"fluent-bit"` | no |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | Log group name fluent-bit will be streaming logs into. | `string` | `"fluentbit-default-log-group"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | If set to a number greater than zero, and newly create log group's retention policy is set to this many days. Valid values are: [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653] | `number` | `0` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | k8s namespace fluent-bit should be deployed into. | `string` | `"kube-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
