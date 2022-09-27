### This is basic usage of module `sso-rbac`

```
module "sso-rbac" {
  source     = "dasmeta/eks/aws//modules/sso-rbac"
  roles      = var.roles
  bindings   = var.bindings
  eks_module = module.eks-cluster.eks_module
  account_id = var.account_id
}

locals {

  roles = [{
    name      = "viewers"
    actions   = ["get", "list", "watch"]
    resources = ["deployments"]
  }, {
    name      = "editors"
    actions   = ["get", "list", "watch"]
    resources = ["pods"]
  }]

  bindings = [{
    group     = "developers"
    namespace = "development"
    roles     = ["viewers", "editors"]

  }, {
    group     = "accountants"
    namespace = "accounting"
    roles     = ["editors"]
 }]
}
```
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
| <a name="module_eks_auth"></a> [eks\_auth](#module\_eks\_auth) | aidanmelen/eks-auth/aws | n/a |
| <a name="module_permission_sets"></a> [permission\_sets](#module\_permission\_sets) | ./terraform-aws-sso/modules/permission-sets | n/a |
| <a name="module_sso_account_assignments"></a> [sso\_account\_assignments](#module\_sso\_account\_assignments) | ./terraform-aws-sso/modules/account-assignments | n/a |

## Resources

| Name | Type |
|------|------|
| [kubernetes_role_binding.example](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_role_v1.k8s-rbac](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_identitystore_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account Id to apply changes into | `string` | n/a | yes |
| <a name="input_bindings"></a> [bindings](#input\_bindings) | Bindings to bind namespace and roles and then pass to kubernetes objects | <pre>list(object({<br>    group     = string<br>    namespace = string<br>    roles     = list(string)<br><br>  }))</pre> | n/a | yes |
| <a name="input_eks_module"></a> [eks\_module](#input\_eks\_module) | terraform-aws-eks module to used for aws-auth update | `any` | n/a | yes |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br>    rolearn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_map_users"></a> [map\_users](#input\_map\_users) | Additional IAM users to add to the aws-auth configmap. | <pre>list(object({<br>    userarn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | Roles to provide kubernetes object | <pre>list(object({<br>    actions   = list(string)<br>    resources = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_yaml"></a> [config\_yaml](#output\_config\_yaml) | n/a |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | n/a |
| <a name="output_role_arns_without_path"></a> [role\_arns\_without\_path](#output\_role\_arns\_without\_path) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
