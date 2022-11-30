<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Allows to enable container/application metrics on k8s cluster

## basic example
```
module "cloudwatch-metrics" {
  source = "dasmeta/modules/aws//modules/cloudwatch-metrics" # change to the correct one.

  eks_oidc_root_ca_thumbprint = ""
  oidc_provider_arn           = module.eks-cluster.oidc_provider_arn
  cluster_name                = "cluster_name"
  enable_prometheus_metrics = false

  providers = {
    kubernetes = kubernetes
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.12.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.12.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.aws-cloudwatch-metrics-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.aws-cloudwatch-metrics](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.aws-cloudwatch-metrics-prometheus](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/2.12.1/docs/resources/namespace) | resource |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | n/a | yes |
| <a name="input_cloudwatch_agent_chart_version"></a> [cloudwatch\_agent\_chart\_version](#input\_cloudwatch\_agent\_chart\_version) | CloudWatch Agent Helm Chart version. | `string` | `"0.0.7"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | eks cluster name | `string` | `""` | no |
| <a name="input_containerd_sock_path"></a> [containerd\_sock\_path](#input\_containerd\_sock\_path) | n/a | `string` | `"/run/dockershim.sock"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | wether or no to create namespace | `bool` | `true` | no |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | n/a | `string` | n/a | yes |
| <a name="input_enable_prometheus_metrics"></a> [enable\_prometheus\_metrics](#input\_enable\_prometheus\_metrics) | n/a | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | namespace cloudwatch metrics should be deployed into | `string` | `"amazon-cloudwatch"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `string` | n/a | yes |
| <a name="input_prometheus_metrics_chart_version"></a> [prometheus\_metrics\_chart\_version](#input\_prometheus\_metrics\_chart\_version) | Version of the prometheus metrics chart to use | `string` | `"0.1.0"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
