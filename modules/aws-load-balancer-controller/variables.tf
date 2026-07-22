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
    version    = optional(string, "3.4.2")
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
    policy_name           = optional(string, null)                              # Optional IAM policy name override
    policy_description    = optional(string, null)                              # Optional IAM policy description override
    role_name             = optional(string, null)                              # Optional IAM role name override
    attachment_method     = optional(string, "service_account_role_annotation") # IAM role attachment mode: service_account_role_annotation or pod_identity_association; set null to manage the association externally
    use_descriptive_names = optional(bool, false)                               # When true, generate descriptive names instead of legacy cluster-based defaults
  })
  default     = {}
  description = "Optional IAM naming controls. Explicit names win when set. When use_descriptive_names is true, names are generated as aws-load-balancer-controller-{cluster_name} and aws-load-balancer-controller-{cluster_name}_iam_role. Otherwise the legacy cluster_name-based defaults are used. Enable by default in new-cluster use cases when possible."

  validation {
    condition = contains(
      ["service_account_role_annotation", "pod_identity_association", null],
      var.iam.attachment_method
    )
    error_message = "iam.attachment_method must be service_account_role_annotation, pod_identity_association, or null for an externally managed association."
  }
}

variable "configs" {
  type = any
  default = {
    # enableServiceMutatorWebhook = "false" # If "false" then it disable the Service Mutator webhook which makes all new services of type LoadBalancer reconciled by the lb controller, TODO: we may need to set this option to false as it fails sometime to apply other helm release in eks module batch
  }
  description = "Configurations to pass and override default ones. Check the chart values here: https://artifacthub.io/packages/helm/aws/aws-load-balancer-controller"
}
