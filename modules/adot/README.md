## basic example
### Important. You should be already setup "cert-manager"

```
module "adot" {
  source = "./modules/adot"

  count = var.enable_adot ? 1 : 0

  cluster_name                = "cluster_name"
  eks_oidc_root_ca_thumbprint = "eks_oidc_root_ca_thumbprint"
  oidc_provider_arn           = "oidc_provider_arn"
  adot_config = {
    drop_namespace_regex = "(cert-manager|kube-public)"
     additional_metrics = {
       "[[PodName, Namespace, ClusterName]]" = [
         "pod_number_of_container_restarts"
       ]

       "[[ClusterName]]" = [
         "cluster_failed_node_count"
       ]
       "[[InstanceId, ClusterName]]" = [
         "node_number_of_running_pods"
       ]
       "[[Deployment, Namespace, ClusterName]]" = [
         "kube_deployment_spec_replicas"
       ]
     }
  }

  depends_on = [
    helm_release.cert-manager
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~>1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~>1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.12 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.adot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_role.adot_collector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.adot-collector](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.this](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.operator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.adot-collector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_adot_collector_policy_arns"></a> [adot\_collector\_policy\_arns](#input\_adot\_collector\_policy\_arns) | List of IAM policy ARNs to attach to the ADOT collector service account. | `list(string)` | <pre>[<br>  "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",<br>  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",<br>  "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"<br>]</pre> | no |
| <a name="input_adot_version"></a> [adot\_version](#input\_adot\_version) | The version of the AWS Distro for OpenTelemetry addon to use. | `string` | `"v0.58.0-eksbuild.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_drop_namespace_regex"></a> [drop\_namespace\_regex](#input\_drop\_namespace\_regex) | Namespace names which metrics we don't want send cloudwatch. Example.(cert-manager\|kube-public) | `string` | `"(cert-manager)"` | no |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install the AWS Distro for OpenTelemetry addon. | `string` | `"adot"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~>1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.12 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~>1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.12 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.adot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_role.adot_collector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.adot-collector](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.this](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.operator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.adot-collector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_adot_collector_policy_arns"></a> [adot\_collector\_policy\_arns](#input\_adot\_collector\_policy\_arns) | List of IAM policy ARNs to attach to the ADOT collector service account. | `list(string)` | <pre>[<br>  "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",<br>  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",<br>  "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"<br>]</pre> | no |
| <a name="input_adot_config"></a> [adot\_config](#input\_adot\_config) | n/a | `any` | <pre>{<br>  "additional_metrics": {},<br>  "drop_namespace_regex": "(cert-manager)"<br>}</pre> | no |
| <a name="input_adot_version"></a> [adot\_version](#input\_adot\_version) | The version of the AWS Distro for OpenTelemetry addon to use. | `string` | `"v0.58.0-eksbuild.1"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `string` | n/a | yes |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install the AWS Distro for OpenTelemetry addon. | `string` | `"adot"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
