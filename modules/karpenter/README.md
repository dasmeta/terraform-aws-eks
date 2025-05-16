
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

 # terraform module allows to create/deploy karpenter operator to have custom/configurable node auto-scaling ability
## for more info check https://karpenter.sh and https://artifacthub.io/packages/helm/karpenter/karpenter

## example
```terraform
module "karpenter" {
  source  = "dasmeta/eks/aws//modules/karpenter"
  version = "2.19.0"

  cluster_name      = "test-cluster-with-karpenter"
  cluster_endpoint  = "<endpoint-to-eks-cluster>"
  oidc_provider_arn = "<eks-oidc-provider-arn>"
  subnet_ids        = ["<subnet-1>", "<subnet-2>", "<subnet-3>"]

  resource_configs = {
      nodePools = {
        general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
        on-demand = {
          # weight = 0 # by default the weight is 0 and this is lowest priority, we can schedule pod in this not
          template = {
            spec = {
              requirements = [
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["on-demand"]
                }
              ]
            }
          }
        }
      }
    }
}
```

**/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_node_classes_custom_default_configs"></a> [ec2\_node\_classes\_custom\_default\_configs](#module\_ec2\_node\_classes\_custom\_default\_configs) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_karpenter_custom_default_configs_merged"></a> [karpenter\_custom\_default\_configs\_merged](#module\_karpenter\_custom\_default\_configs\_merged) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_this"></a> [this](#module\_this) | terraform-aws-modules/eks/aws//modules/karpenter | 20.34.0 |

## Resources

| Name | Type |
|------|------|
| [helm_release.karpenter_nodes](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.this_crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_instance.ec2_from_eks_node_pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instance) | data source |
| [aws_instances.ec2_from_eks_node_pools](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether use helm deploy with --atomic flag | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"1.4.0"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | The eks cluster endpoint | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The eks cluster name | `string` | n/a | yes |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass and override default ones. Check the helm chart available configs here: https://github.com/aws/karpenter-provider-aws/blob/v1.3.3/charts/karpenter/values.yaml | `any` | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `true` | no |
| <a name="input_create_pod_identity_association"></a> [create\_pod\_identity\_association](#input\_create\_pod\_identity\_association) | Determines whether to create pod identity association | `bool` | `true` | no |
| <a name="input_enable_pod_identity"></a> [enable\_pod\_identity](#input\_enable\_pod\_identity) | Determines whether to enable support for EKS pod identity | `bool` | `true` | no |
| <a name="input_enable_v1_permissions"></a> [enable\_v1\_permissions](#input\_enable\_v1\_permissions) | Determines whether to enable permissions suitable for v1+ | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install main helm. | `string` | `"karpenter"` | no |
| <a name="input_node_iam_role_additional_policies"></a> [node\_iam\_role\_additional\_policies](#input\_node\_iam\_role\_additional\_policies) | Additional policies to be added to the IAM role | `any` | `{}` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'. | `string` | n/a | yes |
| <a name="input_resource_chart_version"></a> [resource\_chart\_version](#input\_resource\_chart\_version) | The dasmeta karpenter-nodes chart version | `string` | `"0.1.0"` | no |
| <a name="input_resource_configs"></a> [resource\_configs](#input\_resource\_configs) | Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes | <pre>object({<br/>    ec2NodeClasses = optional(any, {}) # This is for additional node classes configuration, by default it creates ec2NodeClass resource named 'default' and this attaches to all nodepools based on var.resource_configs_defaults configs<br/>    nodePools      = optional(any, {}) # The nodepool resources definition, it uses some predefined/default values from var.resource_configs_defaults which can be customized, check helm chart or/and karpenter docs for schema/fields<br/>  })</pre> | `{}` | no |
| <a name="input_resource_configs_defaults"></a> [resource\_configs\_defaults](#input\_resource\_configs\_defaults) | Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes | <pre>object({<br/>    nodeClass = optional(any, {<br/>      amiFamily          = null # if not specified the value will be identified based on eks managed nodes ami id, the valid values are for example "AL2", "AL2023"<br/>      detailedMonitoring = true<br/>      metadataOptions = {<br/>        httpEndpoint            = "enabled"<br/>        httpProtocolIPv6        = "disabled"<br/>        httpPutResponseHopLimit = 2 # This is changed to disable IMDS access from containers not on the host network<br/>        httpTokens              = "required"<br/>      }<br/>      blockDeviceMappings = [<br/>        {<br/>          deviceName = "/dev/xvda"<br/>          ebs = {<br/>            volumeSize = "100Gi"<br/>            volumeType = "gp3"<br/>            encrypted  = true<br/>          }<br/>        }<br/>      ]<br/>    })<br/>    nodeClassRef = optional(any, {<br/>      group = "karpenter.k8s.aws"<br/>      kind  = "EC2NodeClass"<br/>      name  = "default"<br/>    }),<br/>    requirements = optional(any, [<br/>      {<br/>        key      = "karpenter.k8s.aws/instance-cpu"<br/>        operator = "Lt"<br/>        values   = ["9"] # <=8 core cpu nodes<br/>      },<br/>      {<br/>        key      = "karpenter.k8s.aws/instance-memory"<br/>        operator = "Lt"<br/>        values   = ["33000"] # <=32 Gb memory nodes<br/>      },<br/>      {<br/>        key      = "karpenter.k8s.aws/instance-cpu"<br/>        operator = "Gt"<br/>        values   = ["1"] # > core cpu nodes<br/>      },<br/>      {<br/>        key      = "karpenter.k8s.aws/instance-memory"<br/>        operator = "Gt"<br/>        values   = ["2000"] #  >2Gb Gb memory nodes as k8s struggles to start small ones<br/>      },<br/>      {<br/>        key      = "karpenter.k8s.aws/instance-generation"<br/>        operator = "Gt"<br/>        values   = ["2"] # generation of ec2 instances >2 (like t3a.medium) are more performance and effectiveness<br/>      },<br/>      {<br/>        key      = "kubernetes.io/arch"<br/>        operator = "In"<br/>        values   = ["amd64"] # amd64 linux is main platform arch we will use<br/>      },<br/>      {<br/>        key      = "karpenter.sh/capacity-type"<br/>        operator = "In"<br/>        values   = ["spot", "on-demand"] # both spot and on-demand nodes, it will look at first available spot and if no then on-demand<br/>      }<br/>    ])<br/>    disruption = optional(any, {<br/>      consolidationPolicy = "WhenEmptyOrUnderutilized"<br/>      consolidateAfter    = "3m" # the frequency how often karpenter will check and colocate/disrupt nodes<br/>      budgets = [<br/>        { nodes : "10%" } # allows karpenter to only deprovision/disrupt/recreate 10% of nodes at a time for consolidation/cost-optimization, to have more stable workloads<br/>      ]<br/>    }),<br/>    limits = optional(any, {<br/>      cpu = 10<br/>    })<br/>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | VPC subnet ids used for default Ec2NodeClass as subnet selector. | `list(string)` | n/a | yes |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether use helm deploy with --wait flag | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_metadata"></a> [helm\_metadata](#output\_helm\_metadata) | Helm release metadata |
| <a name="output_karpenter_data"></a> [karpenter\_data](#output\_karpenter\_data) | Karpenter data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
