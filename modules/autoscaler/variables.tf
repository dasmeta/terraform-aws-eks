variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn to pass to policy"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name to pass to role"
}

variable "eks_version" {
  type        = string
  description = "The version of eks cluster"
}

variable "autoscaler_image_patch" {
  type        = number
  description = "The patch number of autoscaler image"
  default     = 0
}
