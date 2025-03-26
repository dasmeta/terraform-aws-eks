variable "cluster_name" {
  description = "K8s cluster name."
  type        = string
}

variable "cluster_version" {
  type        = string
  default     = "1.29"
  description = "Version of eks cluster"
}

variable "most_recent" {
  type        = bool
  default     = true
  description = "Whether to use addon latest compatible version"
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
  description = "The version of the AWS Distro for OpenTelemetry addon to use. If not passed it will get compatible version based on cluster_version and most_recent"
  type        = string
  default     = null
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

variable "chart_version" {
  type        = string
  default     = "0.15.5"
  description = "The app chart version"
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
    logging_enable         = optional(bool, false)
    memory_limiter = optional(object(
      {
        limit_mib      = optional(number, 1000)
        check_interval = optional(string, "1s")
      }
      ), {
      limit_mib      = 1000
      check_interval = "1s"
      }
    )
    resources = optional(object({
      limit = object({
        cpu    = optional(string, "200m")
        memory = optional(string, "200Mi")
      })
      requests = object({
        cpu    = optional(string, "200m")
        memory = optional(string, "200Mi")
      })
      }), {
      limit = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "200Mi"
    } })
  })
  default = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = []
    log_group_name         = "adot"
    log_retention          = 14
    logging_enable         = false
    # ADOT helm chart values.yaml, if you don't use variable adot will be deployed with module default values file
    helm_values = null
    resources = {
      limit = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "200Mi"
      }
    }
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
