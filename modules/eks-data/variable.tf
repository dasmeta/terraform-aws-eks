variable "cluster_name" {
  type        = string
  description = "Cluster Name"
}

variable "get_oidc_provider_data" {
  type        = bool
  default     = false
  description = "Whether to get eks cluster OIDC provider data like arn, thumbprint_list"
}
