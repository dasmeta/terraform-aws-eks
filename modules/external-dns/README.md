# external-dns

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_role"></a> [role](#module\_role) | dasmeta/iam/aws//modules/role | 1.2.1 |

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Enable atomic Helm upgrades for the external-dns release | `bool` | `true` | no |
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | The name of the external-dns Helm chart | `string` | `"external-dns"` | no |
| <a name="input_chart_repository"></a> [chart\_repository](#input\_chart\_repository) | The external-dns chart repository to use | `string` | `"https://kubernetes-sigs.github.io/external-dns"` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The external-dns chart version to use (see https://github.com/kubernetes-sigs/external-dns/releases) | `string` | `"1.20.0"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | K8s cluster name. | `string` | n/a | yes |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass and override default ones. See chart values: https://kubernetes-sigs.github.io/external-dns/latest/charts/external-dns/ | `any` | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install external-dns helm. | `string` | `"external-dns"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region, if not passed it will get region from terraform running current context | `string` | `null` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | The name of the external-dns Helm release | `string` | `"external-dns"` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | The name of service-account to use for accessing aws resources. | `string` | `"external-dns"` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether to wait for external-dns Helm release to be deployed | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_metadata"></a> [helm\_metadata](#output\_helm\_metadata) | Helm release metadata |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Created iam role arn, which was used for attaching to service account |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
