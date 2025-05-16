## basic example
### Important. You should be already setup "cert-manager"

```
module "adot" {
  source = "./modules/adot"

  cluster_name                = "cluster_name"
  eks_oidc_root_ca_thumbprint = "eks_oidc_root_ca_thumbprint"
  oidc_provider_arn           = "oidc_provider_arn"
  adot_config = {
    accept_namespace_regex = "(cert-manager|kube-public)"
      additional_metrics = [
        "pod_number_of_container_restarts"
        "cluster_failed_node_count"
        "node_number_of_running_pods"
        "kube_deployment_spec_replicas"
      ]
  }
  prometheus_metrics = {
    "[[Prometheus]]" = [
      "go_gc_duration_seconds_sum"
    ]
  }

  depends_on = [
    helm_release.cert-manager
  ]
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~>1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~>1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_policy.adot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.adot_collector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.adot-collector](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.this](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.operator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account_v1.adot-collector](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [aws_eks_addon_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_adot_collector_policy_arns"></a> [adot\_collector\_policy\_arns](#input\_adot\_collector\_policy\_arns) | List of IAM policy ARNs to attach to the ADOT collector service account. | `list(string)` | `[]` | no |
| <a name="input_adot_config"></a> [adot\_config](#input\_adot\_config) | accept\_namespace\_regex defines the list of namespaces from which metrics will be exported, and additional\_metrics defines additional metrics to export. | <pre>object({<br/>    accept_namespace_regex = optional(string, "(default|kube-system)")<br/>    additional_metrics     = optional(list(string), [])<br/>    log_group_name         = optional(string, "adot")<br/>    log_retention          = optional(number, 14)<br/>    helm_values            = optional(any, null)<br/>    logging_enable         = optional(bool, false)<br/>    memory_limiter = optional(object(<br/>      {<br/>        limit_mib      = optional(number, 1000)<br/>        check_interval = optional(string, "1s")<br/>      }<br/>      ), {<br/>      limit_mib      = 1000<br/>      check_interval = "1s"<br/>      }<br/>    )<br/>    resources = optional(object({<br/>      limit = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      requests = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      }), {<br/>      limit = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>      }<br/>      requests = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>    } })<br/>  })</pre> | <pre>{<br/>  "accept_namespace_regex": "(default|kube-system)",<br/>  "additional_metrics": [],<br/>  "helm_values": null,<br/>  "log_group_name": "adot",<br/>  "log_retention": 14,<br/>  "logging_enable": false,<br/>  "resources": {<br/>    "limit": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    },<br/>    "requests": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_adot_log_group_name"></a> [adot\_log\_group\_name](#input\_adot\_log\_group\_name) | ADOT log group name | `string` | `"adot_log_group_name"` | no |
| <a name="input_adot_version"></a> [adot\_version](#input\_adot\_version) | The version of the AWS Distro for OpenTelemetry addon to use. If not passed it will get compatible version based on cluster\_version and most\_recent | `string` | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"0.15.5"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | K8s cluster name. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Version of eks cluster | `string` | `"1.30"` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `false` | no |
| <a name="input_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#input\_eks\_oidc\_root\_ca\_thumbprint) | EKS oidc root ca thumbprint. | `string` | n/a | yes |
| <a name="input_most_recent"></a> [most\_recent](#input\_most\_recent) | Whether to use addon latest compatible version | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install the AWS Distro for OpenTelemetry addon. | `string` | `"meta-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKC oidc provider arn. | `string` | n/a | yes |
| <a name="input_prometheus_metrics"></a> [prometheus\_metrics](#input\_prometheus\_metrics) | Prometheus Metrics | `any` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
