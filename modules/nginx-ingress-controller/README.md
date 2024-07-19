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

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.ingress-nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace or use existing one | `bool` | `true` | no |
| <a name="input_metrics_enabled"></a> [metrics\_enabled](#input\_metrics\_enabled) | Enable metric export | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Name | `string` | `"nginx"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace name | `string` | `"ingress-nginx"` | no |
| <a name="input_replicacount"></a> [replicacount](#input\_replicacount) | Nginx Ingress controller replica count | `number` | `3` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
