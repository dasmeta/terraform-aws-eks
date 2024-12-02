variable "account_id" {
  type        = string
  description = "AWS Account Id to apply changes into"
}

variable "region" {
  type        = string
  description = "AWS Region name."
}

variable "cloudwatch_agent_chart_version" {
  type        = string
  description = "CloudWatch Agent Helm Chart version."
  default     = "0.0.11"
}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "eks cluster name"
}

variable "namespace" {
  type        = string
  default     = "amazon-cloudwatch"
  description = "namespace cloudwatch metrics should be deployed into"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "wether or no to create namespace"
}

variable "containerd_sock_path" {
  type    = string
  default = "/run/dockershim.sock"
}

variable "eks_oidc_root_ca_thumbprint" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "enable_prometheus_metrics" {
  type    = bool
  default = false
}

variable "prometheus_metrics_chart_version" {
  description = "Version of the prometheus metrics chart to use"
  type        = string
  default     = "0.2.0"
}

variable "prometheus_metrics_debug" {
  description = "Enable debug logging for the prometheus metrics chart"
  type        = bool
  default     = false
}
