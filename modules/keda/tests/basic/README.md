# basic

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
| <a name="module_keda"></a> [keda](#module\_keda) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_sqs_queue.worker_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_keda_iam_role_arn"></a> [keda\_iam\_role\_arn](#output\_keda\_iam\_role\_arn) | IAM Role ARN for KEDA to access SQS |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
