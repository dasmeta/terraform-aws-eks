```
module "cluster_min" {
  source = "dasmeta/eks/aws"
  version = "1.10.0"

  cluster_name                = local.cluster_name
  send_alb_logs_to_cloudwatch = false
  alb_log_bucket_name         = "log_bucket"
  cluster_version             = "1.23"
  users                       = local.users
  map_roles                   = local.map_roles
  vpc_name                    = local.vpc_name
  cidr                        = local.cidr
  node_groups_default = local.node_groups_default
  node_groups = local.node_groups
  availability_zones          = local.availability_zones
  private_subnets             = local.private_subnets
  public_subnets              = local.public_subnets
  public_subnet_tags          = local.public_subnet_tags
  private_subnet_tags         = local.private_subnet_tags
  account_id                  = data.aws_caller_identity.current.account_id

  # EFS Usage #
  enable_efs_driver = true
  efs_id = "fs-0cd302bd75cfc6dd8"

}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Main complete cluster submodule which will create eks common resources

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_auth_config_map"></a> [aws\_auth\_config\_map](#module\_aws\_auth\_config\_map) | terraform-aws-modules/eks/aws//modules/aws-auth | 20.29.0 |
| <a name="module_eks-cluster"></a> [eks-cluster](#module\_eks-cluster) | terraform-aws-modules/eks/aws | 20.30.1 |

## Resources

| Name | Type |
|------|------|
| [null_resource.enable_cloudwatch_metrics_autoscaling](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_user.user_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | Cluster addon configurations to enable. | `any` | `{}` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html) | `list(string)` | <pre>[<br>  "audit"<br>]</pre> | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | When you create EKS, API server endpoint access default is public. When you use private this variable value should be equal false | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Creating cluster name. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Cluster version. | `string` | `"1.22"` | no |
| <a name="input_enable_irsa"></a> [enable\_irsa](#input\_enable\_irsa) | Whether or not to enable OpenID connect protocol. | `bool` | `true` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br>    rolearn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node group definitions to create | `any` | <pre>{<br>  "default": {<br>    "desired_size": 1,<br>    "instance_types": [<br>      "t3.medium"<br>    ],<br>    "max_size": 2,<br>    "min_size": 1<br>  }<br>}</pre> | no |
| <a name="input_node_groups_default"></a> [node\_groups\_default](#input\_node\_groups\_default) | Map of EKS managed node group default configurations | `any` | <pre>{<br>  "disk_size": 50,<br>  "instance_types": [<br>    "t3.medium"<br>  ]<br>}</pre> | no |
| <a name="input_node_security_group_additional_rules"></a> [node\_security\_group\_additional\_rules](#input\_node\_security\_group\_additional\_rules) | n/a | `any` | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | VPC subnets. Most probably those are the private ones. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to attach to eks cluster. | `any` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to open eks cluster api access | `list(any)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id where to spin up the cluster. | `string` | n/a | yes |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | self\_managed\_node\_group\_defaults. | `any` | `{}` | no |
| <a name="input_workers_group_defaults"></a> [workers\_group\_defaults](#input\_workers\_group\_defaults) | Map of self-managed node group definitions to create. | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_auth_module"></a> [aws\_auth\_module](#output\_aws\_auth\_module) | n/a |
| <a name="output_certificate"></a> [certificate](#output\_certificate) | n/a |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The cluster\_id has been deprecated and replaced with cluster\_name starting from module version v19.x |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | n/a |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | n/a |
| <a name="output_eks_module"></a> [eks\_module](#output\_eks\_module) | n/a |
| <a name="output_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#output\_eks\_oidc\_root\_ca\_thumbprint) | Grab eks\_oidc\_root\_ca\_thumbprint from oidc\_provider\_arn. |
| <a name="output_host"></a> [host](#output\_host) | n/a |
| <a name="output_map_users_data"></a> [map\_users\_data](#output\_map\_users\_data) | n/a |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | n/a |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | VPC subnet ids used for eks |
| <a name="output_token"></a> [token](#output\_token) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
