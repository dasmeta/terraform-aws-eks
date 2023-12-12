variable "cluster_name" {
  description = "K8s cluster name."
  type        = string
}

variable "eks_oidc_root_ca_thumbprint" {
  description = "EKS oidc root ca thumbprint."
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKC oidc provider arn."
  type        = string
}

variable "adot_version" {
  description = "The version of the AWS Distro for OpenTelemetry addon to use."
  type        = string
  default     = "v0.78.0-eksbuild.1"
}

variable "namespace" {
  description = "The namespace to install the AWS Distro for OpenTelemetry addon."
  type        = string
  default     = "meta-system"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Create namespace if requested"
}

variable "adot_collector_policy_arns" {
  description = "List of IAM policy ARNs to attach to the ADOT collector service account."
  type        = list(string)
  default     = []
}

variable "adot_config" {
  description = "accept_namespace_regex defines the list of namespaces from which metrics will be exported, and additional_metrics defines additional metrics to export."
  type = object({
    accept_namespace_regex = optional(string, "(default|kube-system)")
    additional_metrics     = optional(list(string), [])
    log_group_name         = optional(string, "adot")
    log_retention          = optional(number, 14)
    helm_values            = optional(any, null)
  })
  default = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = []
    log_group_name         = "adot"
    log_retention          = 21
    # ADOT helm chart values.yaml, if you don't use variable adot will be deployed with module default values file
    helm_values = null
  }
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "prometheus_metrics" {
  description = "Prometheus Metrics"
  type        = any
  default     = []
}

variable "adot_log_group_name" {
  description = "ADOT log group name"
  type        = string
  default     = "adot_log_group_name"
}
