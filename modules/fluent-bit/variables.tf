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

variable "create_log_group" {
  type        = bool
  default     = true
  description = "Wether or no to create log group."
}

variable "log_retention_days" {
  description = "If set to a number greater than zero, and newly create log group's retention policy is set to this many days. Valid values are: [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653]"
  type        = number
  default     = 90
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Invalid value for log_retention days '${var.log_retention_days}'. Valid values are: [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653]"
  }
}

variable "values_yaml" {
  description = "Content of the values.yaml given to the helm chart. This disables the rendered values.yaml file from this module."
  default     = null
  type        = string
}

variable "s3_permission" {
  description = "If you want send logs to s3 you should enable s3 permission"
  default     = false
  type        = bool
}
