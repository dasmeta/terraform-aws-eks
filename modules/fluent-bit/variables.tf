data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS Region fluent-bit will be streaming logs to."
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

# Auth data

# variable "cluster_host" {
#   type = string
# }

# variable "cluster_certificate" {
#   type = string
# }

# variable "cluster_token" {
#   type = string
# }

variable "log_group_name" {
  type        = string
  default     = "fluentbit-default-log-group"
  description = "Log group name fluent-bit will be streaming logs into."
}
