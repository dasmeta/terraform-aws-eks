<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Creates aws load balancer controller on eks cluster

# todo
- automate shell script contents via terraform
- test and remove waf related values from helm
- re-consider namespace

https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.aws-load-balancer-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.AWSLoadBalancerControllerIAMPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.aws-load-balancer-controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"1.10.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | eks cluster name | `string` | `""` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | wether or no to create namespace | `bool` | `false` | no |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | n/a | `string` | n/a | yes |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | Enables WAF and WAF V2 addons for ALB | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | namespace load balancer controller should be deployed into | `string` | `"kube-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign to the object. | `any` | `null` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
