# AWS EKS S3-CSI driver ("aws-mountpoint-s3-csi-driver")

### This module provides ability to enable S3-CSI driver on eks


```
module "this" {
  source  = "dasmeta/eks/aws//modules/s3-csi"

  cluster_name = "my-eks-cluster"
  oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>"
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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_iam_role_for_service_accounts_eks"></a> [iam\_role\_for\_service\_accounts\_eks](#module\_iam\_role\_for\_service\_accounts\_eks) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.55.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_version"></a> [addon\_version](#input\_addon\_version) | Version of S3-CSI driver to use, if not passed the latest compatible version will be set based on cluster\_version and most\_recent | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS Cluster name for addon | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Version of eks cluster | `string` | `"1.30"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | Pass additional addon config and override default ones | `any` | <pre>{<br/>  "node": {<br/>    "tolerateAllTaints": true<br/>  }<br/>}</pre> | no |
| <a name="input_most_recent"></a> [most\_recent](#input\_most\_recent) | Whether to use addon latest compatible version | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where addon pods getting placed. | `string` | `"kube-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | Cluster OIDC arn for policy configuration in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>' | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region, if not set the region will be fetched from provider/caller current context | `string` | `null` | no |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | The list of aws s3 bucket to which we will need to have access from inside eks cluster by using bucket mount as volume. NOTE: if no bucket passed then full access to s3 buckets being used | `list(string)` | `[]` | no |
| <a name="input_serviceAccount"></a> [serviceAccount](#input\_serviceAccount) | The name of eks service account. | `string` | `"s3-csi-driver-sa"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_addon_arn"></a> [addon\_arn](#output\_addon\_arn) | The arn of installed/created addon |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The arn of service account role |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
