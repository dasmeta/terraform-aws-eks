variable "cluster_name" {
  type        = string
  description = "The eks cluster name"
}

variable "oidc_provider_arn" {
  description = "EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'."
  type        = string
}

variable "cluster_endpoint" {
  type        = string
  description = "The eks cluster endpoint"
}

variable "subnet_ids" {
  type        = list(string)
  description = "VPC subnet ids used for default Ec2NodeClass as subnet selector."
}

variable "enable_v1_permissions" {
  description = "Determines whether to enable permissions suitable for v1+"
  type        = bool
  default     = true
}

variable "enable_pod_identity" {
  type        = bool
  default     = true
  description = "Determines whether to enable support for EKS pod identity"
}

variable "create_pod_identity_association" {
  type        = bool
  default     = true
  description = "Determines whether to create pod identity association"
}

variable "node_iam_role_additional_policies" {
  type        = any
  default     = {}
  description = "Additional policies to be added to the IAM role"
}

variable "chart_version" {
  type        = string
  default     = "1.3.3"
  description = "The app chart version"
}

variable "resource_chart_version" {
  type        = string
  default     = "0.1.0"
  description = "The dasmeta karpenter-nodes chart version"
}

variable "namespace" {
  description = "The namespace to install main helm."
  type        = string
  default     = "karpenter"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create namespace if requested"
}

variable "atomic" {
  type        = bool
  default     = false
  description = "Whether use helm deploy with --atomic flag"
}

variable "wait" {
  type        = bool
  default     = true
  description = "Whether use helm deploy with --wait flag"
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://github.com/aws/karpenter-provider-aws/blob/v1.0.8/charts/karpenter/values.yaml"
}

variable "resource_configs" {
  type = object({
    ec2NodeClasses = optional(any, {}) # This is for additional node classes configuration, by default it creates ec2NodeClass resource named 'default' and this attaches to all nodepools based on var.resource_configs_defaults configs
    nodePools      = optional(any, {}) # The nodepool resources definition, it uses some predefined/default values from var.resource_configs_defaults which can be customized, check helm chart or/and karpenter docs for schema/fields
  })
  default     = {}
  description = "Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes"
}

variable "resource_configs_defaults" {
  type = object({
    nodeClass = optional(any, {
      amiFamily          = null # if not specified the value will be identified based on eks managed nodes ami id, the valid values are for example "AL2", "AL2023"
      detailedMonitoring = true
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2 # This is changed to disable IMDS access from containers not on the host network
        httpTokens              = "required"
      }
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize = "100Gi"
            volumeType = "gp3"
            encrypted  = true
          }
        }
      ]
    })
    nodeClassRef = optional(any, {
      group = "karpenter.k8s.aws"
      kind  = "EC2NodeClass"
      name  = "default"
    }),
    requirements = optional(any, [
      {
        key      = "karpenter.k8s.aws/instance-cpu"
        operator = "Lt"
        values   = ["9"] # <=8 core cpu nodes
      },
      {
        key      = "karpenter.k8s.aws/instance-memory"
        operator = "Lt"
        values   = ["33000"] # <=32 Gb memory nodes
      },
      {
        key      = "karpenter.k8s.aws/instance-cpu"
        operator = "Gt"
        values   = ["1"] # > core cpu nodes
      },
      {
        key      = "karpenter.k8s.aws/instance-memory"
        operator = "Gt"
        values   = ["2000"] #  >2Gb Gb memory nodes as k8s struggles to start small ones
      },
      {
        key      = "karpenter.k8s.aws/instance-generation"
        operator = "Gt"
        values   = ["2"] # generation of ec2 instances >2 (like t3a.medium) are more performance and effectiveness
      },
      {
        key      = "kubernetes.io/arch"
        operator = "In"
        values   = ["amd64"] # amd64 linux is main platform arch we will use
      },
      {
        key      = "karpenter.sh/capacity-type"
        operator = "In"
        values   = ["spot", "on-demand"] # both spot and on-demand nodes, it will look at first available spot and if no then on-demand
      }
    ])
    disruption = optional(any, {
      consolidationPolicy = "WhenEmptyOrUnderutilized"
      consolidateAfter    = "3m" # the frequency how often karpenter will check and colocate/disrupt nodes
      budgets = [
        { nodes : "10%" } # allows karpenter to only deprovision/disrupt/recreate 10% of nodes at a time for consolidation/cost-optimization, to have more stable workloads
      ]
    }),
    limits = optional(any, {
      cpu = 10
    })
  })
  default     = {}
  description = "Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes"
}
