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

variable "chart_version" {
  type        = string
  default     = "0.48.1"
  description = "Fluent-bit chart version to use."
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

variable "system_log_group_name" {
  type        = string
  default     = ""
  description = "Log group name fluent-bit will be streaming kube-system logs."
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
  description = "Content of the values.yaml if you want override all default configs."
  default     = ""
  type        = string
}

variable "fluent_bit_config" {
  description = "You can add other inputs,outputs and filters which module doesn't have by default"
  default = {
    inputs                     = ""
    outputs                    = ""
    filters                    = ""
    cloudwatch_outputs_enabled = true # whether to disable default cloudwatch exporter/output
  }
  type = any
}

variable "s3_permission" {
  description = "If you want send logs to s3 you should enable s3 permission"
  default     = false
  type        = bool
}

variable "drop_namespaces" {
  type = list(string)
  default = [
    "kube-system",
    "opentelemetry-operator-system",
    "adot",
    "cert-manager",
    "opentelemetry.*",
    "meta.*",
  ]
  description = "Flunt bit doesn't send logs for this namespaces"
}

variable "kube_namespaces" {
  type = list(string)
  default = [
    "kube.*",
    "meta.*",
    "adot.*",
    "devops.*",
    "cert-manager.*",
    "git.*",
    "opentelemetry.*",
    "stakater.*",
    "renovate.*"
  ]
  description = "Kubernates namespaces"
}

variable "log_filters" {
  type = list(string)
  default = [
    "kube-probe",
    "health",
    "prometheus",
    "liveness"
  ]
  description = "Fluent bit doesn't send logs if message consists of this values"
}

variable "additional_log_filters" {
  type = list(string)
  default = [
    "ELB-HealthChecker",
    "Amazon-Route53-Health-Check-Service",
  ]
  description = "Fluent bit doesn't send logs if message consists of this values"
}

variable "image_pull_secrets" {
  type        = list(string)
  default     = []
  description = "Secret name which can we use for download image"
}
