variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn to pass to policy"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name to pass to role"
}

variable "chart_version" {
  description = "Chart version of api-gw"
  type        = string
  default     = "0.0.17"
}
