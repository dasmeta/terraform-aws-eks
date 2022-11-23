# portainer

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
| [helm_release.portainer](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_ingress"></a> [enable\_ingress](#input\_enable\_ingress) | Weather create ingress or not in k8s | `bool` | `true` | no |
| <a name="input_host"></a> [host](#input\_host) | Ingress host name | `string` | `"portainer.dasmeta.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_portainer_host"></a> [portainer\_host](#output\_portainer\_host) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
