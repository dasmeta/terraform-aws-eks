variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for addon"
}

variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn for policy configuration"
}

variable "addon_version" {
  type        = string
  default     = null
  description = "Version of EBS-CSI driver to use, if not passed the latest compatible version will be set based on cluster_version and most_recent"
}

variable "cluster_version" {
  type        = string
  default     = "1.30"
  description = "Version of eks cluster"
}

variable "most_recent" {
  type        = bool
  default     = true
  description = "Whether to use addon latest compatible version"
}
