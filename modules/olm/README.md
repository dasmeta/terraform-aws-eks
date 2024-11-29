# olm

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.23 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_yaml"></a> [yaml](#module\_yaml) | dasmeta/helpers/null//modules/yaml | 0.0.1 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.olm](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_version_tag"></a> [version\_tag](#input\_version\_tag) | OlM version | `string` | `"v0.30.0"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
