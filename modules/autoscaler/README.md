# AWS EKS AUTOSCALER

### This module provides ability to enable autoscaling on EKS cluster

#### To enable autoscaler on root module you just need to set

```
module "eks" {
      source  = "dasmeta/eks/aws"

      ...
      autoscaling = true
      autoscaler_image_patch = 0 #(optional default is 0)
      scale_down_unneeded_time = 3 #(scale down unneeded time in minutes, default is 2)
      ...
}
```

#### You can also modify resource requests and limits directly in module

```
module "eks" {
      source  = "dasmeta/eks/aws"

      ...
      autoscaling = true
      autoscaler_image_patch = 0 #(optional default is 0)
      scale_down_unneeded_time = 3 #(scale down unneeded time in minutes, default is 2)

        autoscaler_requests = {
          cpu = "100m"
          memory = "600Mi"
          }
        autoscaler_limits = {
          cpu = "100m"
          memory = "600Mi"
          }
      ...

}
```

# autoscaler

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~>2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~>2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [kubernetes_cluster_role.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_deployment.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment) | resource |
| [kubernetes_role.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_service_account.cluster-autoscaler](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscaler_image_patch"></a> [autoscaler\_image\_patch](#input\_autoscaler\_image\_patch) | The patch number of autoscaler image | `number` | `0` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name to pass to role | `string` | n/a | yes |
| <a name="input_cluster_oidc_arn"></a> [cluster\_oidc\_arn](#input\_cluster\_oidc\_arn) | Cluster OIDC arn to pass to policy | `string` | n/a | yes |
| <a name="input_eks_version"></a> [eks\_version](#input\_eks\_version) | The version of eks cluster | `string` | `"1.32"` | no |
| <a name="input_limits"></a> [limits](#input\_limits) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_requests"></a> [requests](#input\_requests) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_scale_down_unneeded_time"></a> [scale\_down\_unneeded\_time](#input\_scale\_down\_unneeded\_time) | Scale down unneeded in minutes | `number` | `2` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
