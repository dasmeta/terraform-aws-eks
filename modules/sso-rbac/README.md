<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_permission_sets"></a> [permission\_sets](#module\_permission\_sets) | github.com/cloudposse/terraform-aws-sso.git//modules/permission-sets | master |
| <a name="module_sso_account_assignments"></a> [sso\_account\_assignments](#module\_sso\_account\_assignments) | github.com/cloudposse/terraform-aws-sso.git//modules/account-assignments | master |

## Resources

| Name | Type |
|------|------|
| [kubernetes_role_binding.example](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_role_v1.k8s-rbac](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_identitystore_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_group) | data source |
| [aws_ssoadmin_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | n/a | `string` | n/a | yes |
| <a name="input_bindings"></a> [bindings](#input\_bindings) | n/a | <pre>list(object({<br>    group     = string<br>    namespace = string<br>    roles     = list(string)<br><br>  }))</pre> | n/a | yes |
| <a name="input_eks_module"></a> [eks\_module](#input\_eks\_module) | n/a | `any` | n/a | yes |
| <a name="input_map_accounts"></a> [map\_accounts](#input\_map\_accounts) | Additional AWS account numbers to add to the aws-auth configmap. | `list(string)` | `[]` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br>    rolearn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_map_users"></a> [map\_users](#input\_map\_users) | Additional IAM users to add to the aws-auth configmap. | <pre>list(object({<br>    userarn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | n/a | <pre>list(object({<br>    actions   = list(string)<br>    resources = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arns"></a> [arns](#output\_arns) | n/a |
| <a name="output_arns_without_path"></a> [arns\_without\_path](#output\_arns\_without\_path) | n/a |
| <a name="output_data_ssoadmin_instances"></a> [data\_ssoadmin\_instances](#output\_data\_ssoadmin\_instances) | n/a |
| <a name="output_iam_permission_set_arns"></a> [iam\_permission\_set\_arns](#output\_iam\_permission\_set\_arns) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
