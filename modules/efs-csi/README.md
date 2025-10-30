## EFS module integration example with main module

```
module "eks" {
  source  = "dasmeta/eks/aws"
  version = "1.7.1"

  cluster_name        = local.cluster_name
  users               = local.users
  vpc_name            = local.vpc_name
  cidr                = local.cidr
  availability_zones  = local.availability_zones
  private_subnets     = local.private_subnets
  public_subnets      = local.public_subnets
  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags

  enable_efs_driver = true
  efs_id = "<efs_id>"
}
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31, < 6.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [helm_release.efs-driver](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_service_account.servciceaccount](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_storage_class.efs_storage_class](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"3.1.8"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Parent cluster name | `string` | n/a | yes |
| <a name="input_cluster_oidc_arn"></a> [cluster\_oidc\_arn](#input\_cluster\_oidc\_arn) | oidc arn of cluster | `string` | n/a | yes |
| <a name="input_efs_id"></a> [efs\_id](#input\_efs\_id) | Id of EFS filesystem in AWS (Required) | `string` | n/a | yes |
| <a name="input_storage_classes"></a> [storage\_classes](#input\_storage\_classes) | Additional storage class configurations: by default, 2 storage classes are created - efs-sc and efs-sc-root which has 0 uid. One can add another storage classes besides these 2. | <pre>list(object({<br/>    name : string<br/>    provisioning_mode : optional(string, "efs-ap")<br/>    file_system_id : string<br/>    directory_perms : optional(string, "755")<br/>    base_path : optional(string, "/")<br/>    uid : optional(number)<br/>  }))</pre> | `[]` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
