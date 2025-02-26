# keda

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~>1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~>1.14 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.keda_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.keda-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_keda_sqs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.keda](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.keda_trigger_authentication](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.keda_trigger_authentication_additional](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_openid_connect_provider.eks_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attach_policies"></a> [attach\_policies](#input\_attach\_policies) | The type of scaling mechanism (e.g., sqs, redis, custom) | <pre>object({<br>    sqs = bool<br>  })</pre> | <pre>{<br>  "sqs": false<br>}</pre> | no |
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | Chart name | `string` | `"keda"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create Namespace to deploy KEDA | `bool` | `true` | no |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | Cluster name | `string` | n/a | yes |
| <a name="input_keda_trigger_auth_additional"></a> [keda\_trigger\_auth\_additional](#input\_keda\_trigger\_auth\_additional) | This variable stores the YAML configuration for a KEDA `TriggerAuthentication` resource. It is used to define authentication settings for KEDA to interact with external cloud providers such as AWS. Module have default for aws you can use default(keda-trigger-auth-default) | `any` | `null` | no |
| <a name="input_keda_version"></a> [keda\_version](#input\_keda\_version) | Version of the KEDA Helm chart | `string` | `"2.16.1"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name to deploy KEDA | `string` | `"keda"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to deploy KEDA | `string` | `"keda"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_keda_iam_role_arn"></a> [keda\_iam\_role\_arn](#output\_keda\_iam\_role\_arn) | IAM Role ARN for KEDA to access SQS |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
