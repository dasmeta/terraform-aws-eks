# AWS EKS EBS-CSI driver

### This module provides ability to enable EBS-CSI driver

In version of 1.23 EKS doesn't come with EBS-CSI driver, so it's very important to consider this
when upgrading
#### To enable EBS-CSI driver on root module you just need to set

```
module "eks" {
      source  = "dasmeta/eks/aws"
      ...
      enable_ebs_driver = true
      ...
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.addons](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_addon_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_version"></a> [addon\_version](#input\_addon\_version) | Version of EBS-CSI driver to use, if not passed the latest compatible version will be set based on cluster\_version and most\_recent | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS Cluster name for addon | `string` | n/a | yes |
| <a name="input_cluster_oidc_arn"></a> [cluster\_oidc\_arn](#input\_cluster\_oidc\_arn) | Cluster OIDC arn for policy configuration | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Version of eks cluster | `string` | `"1.31"` | no |
| <a name="input_most_recent"></a> [most\_recent](#input\_most\_recent) | Whether to use addon latest compatible version | `bool` | `true` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
