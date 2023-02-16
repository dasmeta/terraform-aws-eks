variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for addon"
}

variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn for policy configurtion"
}
