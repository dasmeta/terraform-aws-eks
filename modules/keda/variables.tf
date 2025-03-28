variable "name" {
  description = "Name to deploy KEDA"
  type        = string
  default     = "keda"
}

variable "namespace" {
  description = "Namespace to deploy KEDA"
  type        = string
  default     = "keda"
}

variable "create_namespace" {
  description = "Create Namespace to deploy KEDA"
  type        = bool
  default     = true
}

variable "keda_version" {
  description = "Version of the KEDA Helm chart"
  type        = string
  default     = "2.16.1"
}

variable "chart_name" {
  description = "Chart name"
  type        = string
  default     = "keda"
}

variable "account_id" {
  type        = string
  description = "The aws account id. if not passed the id will be identified based on current aws provider context"
  default     = null
}

variable "eks_cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "oidc_provider_arn" {
  description = "EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'. If not provided, this value will be fetched from based on var.eks_cluster_name"
  type        = string
  default     = null
}

variable "attach_policies" {
  type = object({
    sqs = bool
  })
  default = {
    sqs = false
  }
  description = "The type of scaling mechanism (e.g., sqs, redis, custom)"
}

variable "keda_trigger_auth_additional" {
  type        = any
  default     = null
  description = "This variable stores the YAML configuration for a KEDA `TriggerAuthentication` resource. It is used to define authentication settings for KEDA to interact with external cloud providers such as AWS. Module have default for aws you can use default(keda-trigger-auth-default)"
}
