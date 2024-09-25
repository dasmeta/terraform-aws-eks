# priority-class

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

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_priority_class.example](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/priority_class) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_priority_class"></a> [priority\_class](#input\_priority\_class) | Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high', 'medium' and 'low' . You can also provide a custom list of Priority Classes if needed. | `list(any)` | <pre>[<br>  {}<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_priority_class"></a> [priority\_class](#output\_priority\_class) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
