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
| [kubernetes_priority_class.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/priority_class) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_priority_classes"></a> [additional\_priority\_classes](#input\_additional\_priority\_classes) | Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high'(1000000), 'medium'(500000) and 'low'(250000) . You can also provide a custom list of Priority Classes if needed. | <pre>list(object({<br>    name  = string<br>    value = string # number in string form<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_priority_class"></a> [priority\_class](#output\_priority\_class) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
