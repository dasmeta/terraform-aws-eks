variable "region" {
  type        = string
  description = "AWS Region name."
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "eks cluster name"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "namespace load balancer controller should be deployed into"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "wether or no to create namespace"
}

variable "service_account_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "The service account name to attach balancer deployment"
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "OIDC provider ARN used for the IRSA trust policy. If not provided, it is resolved from the EKS cluster identified by cluster_name."
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "The AWS VPC Id where EKS deployed. Issue https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/3695"
}

variable "enable_waf" {
  type        = bool
  description = "Enables WAF and WAF V2 addons for ALB"
  default     = false
}

variable "chart" {
  type = object({
    version    = optional(string, "3.3.0")
    repository = optional(string, "https://aws.github.io/eks-charts")
    name       = optional(string, "aws-load-balancer-controller")
  })
  default     = {}
  description = "Chart source settings. name can be a chart name or a direct packaged-chart URL ending with .tgz; repository is ignored for direct URLs."
}

variable "image" {
  type = object({
    repository = optional(string, null)
    tag        = optional(string, null)
  })
  default     = {}
  description = "Optional controller image override. When repository/tag are null, the chart default image is used."
}

variable "iam" {
  type = object({
    policy_name = optional(string, null)
    role_name   = optional(string, null)
  })
  default     = {}
  description = "Optional IAM naming overrides. When null, names are generated from cluster_name."
}

variable "use_service_account_role_annotation" {
  type        = bool
  default     = true
  description = "Whether to attach the IAM role to the controller service account through the eks.amazonaws.com/role-arn annotation."
}

variable "create_pod_identity_association" {
  type        = bool
  default     = false
  description = "Whether to create an EKS Pod Identity association for the controller service account."
}

variable "configs" {
  type = any
  default = {
    # enableServiceMutatorWebhook = "false" # If "false" then it disable the Service Mutator webhook which makes all new services of type LoadBalancer reconciled by the lb controller, TODO: we may need to set this option to false as it fails sometime to apply other helm release in eks module batch
  }
  description = "Configurations to pass and override default ones. Check the chart values here: https://artifacthub.io/packages/helm/aws/aws-load-balancer-controller"
}
