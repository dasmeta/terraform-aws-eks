variable "account_id" {
  type        = string
  description = "AWS Account Id to apply changes into"
}

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
