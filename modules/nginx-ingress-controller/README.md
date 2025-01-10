# nginx-ingress-controller

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_default_configs_merged"></a> [custom\_default\_configs\_merged](#module\_custom\_default\_configs\_merged) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |

## Resources

| Name | Type |
|------|------|
| [helm_release.ingress-nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"4.12.0"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.12.0?modal=values | `any` | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace or use existing one | `bool` | `true` | no |
| <a name="input_metrics_enabled"></a> [metrics\_enabled](#input\_metrics\_enabled) | Enable metric export | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Name | `string` | `"nginx"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace name | `string` | `"ingress-nginx"` | no |
| <a name="input_replicacount"></a> [replicacount](#input\_replicacount) | Nginx Ingress controller replica count | `number` | `3` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
