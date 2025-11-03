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

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31, < 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_storage_classes"></a> [storage\_classes](#module\_storage\_classes) | ./modules/storage-classes | n/a |

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
| <a name="input_storage_classes"></a> [storage\_classes](#input\_storage\_classes) | The eks ebs-csi StorageClasses to create/configure. We have predefined StorageClasses: ebs-gp3, ebs-gp2, ebs-io2-3k, ebs-io2-5k, ebs-io2-8k, ebs-io2-16k, ebs-io2-32k, ebs-io2-64k, ebs-st1 and ebs-sc1. This ones can be customized or extended with additional ones by using var.storage\_classes.extra\_configs | <pre>object({<br/>    defaults = optional(object({                                        # defaults to pass StorageClass<br/>      enabled                = optional(bool, true)                     # whether storage class enabled<br/>      default                = optional(bool, false)                    # whether storage class is default<br/>      storage_provisioner    = optional(string, "ebs.csi.aws.com")      # provisioner to use for storage class<br/>      volume_binding_mode    = optional(string, "WaitForFirstConsumer") # when volume binding and dynamic provisioning should occur<br/>      allow_volume_expansion = optional(bool, true)                     # whether the storage class allow volume expand<br/>      reclaim_policy         = optional(string, "Retain")               # whether to "Retain" or "Delete" pv on pvc removal<br/>      mount_options          = optional(list(string), [])               # mount options to set, for example ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]<br/>      parameters = optional(object({<br/>        fsType    = optional(string, "ext4") # the filesystem of the volume<br/>        encrypted = optional(string, "true") # whether to have storage encrypted<br/>        kmsKeyId  = optional(string, null)   # the custom kms key to pass to encrypt storage when encrypted=true, by default aws managed key will be used<br/>      }), {})<br/>    }), {})<br/>    extra_configs = optional(any, {}) # the map of {class-name}=>{class-configs} to customize predefined ones or create additional StorageClasses, the {class-configs} object has same field as var.storage_classes.defaults<br/>  })</pre> | `{}` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
