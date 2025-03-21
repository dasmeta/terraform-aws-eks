# eks-with-karpenter-and-external-secret

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.90.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_secret_manager"></a> [secret\_manager](#module\_secret\_manager) | dasmeta/modules/aws//modules/secret | 2.6.2 |
| <a name="module_secret_store"></a> [secret\_store](#module\_secret\_store) | dasmeta/modules/aws//modules/external-secret-store | 2.18.1 |
| <a name="module_this"></a> [this](#module\_this) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.http_echo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpcs.ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
