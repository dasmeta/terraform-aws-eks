variable "account_id" {
  type        = string
  description = "AWS Account Id to apply changes into"
}

variable "region" {
  type        = string
  description = "AWS Region name."
}

variable "fluent_bit_name" {
  type        = string
  default     = "fluent-bit"
  description = "Container resource name."
}

variable "cluster_name" {
  type        = string
  description = "AWS EKS Cluster name."
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "k8s namespace fluent-bit should be deployed into."
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Wether or no to create namespace."
}

variable "eks_oidc_root_ca_thumbprint" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "log_group_name" {
  type        = string
  default     = "fluentbit-default-log-group"
  description = "Log group name fluent-bit will be streaming logs into."
}
