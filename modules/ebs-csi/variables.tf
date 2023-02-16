variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for addon"
}

variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn for policy configurtion"
}

variable "addon_version" {
  type        = string
  default     = "v1.15.0-eksbuild.1"
  description = "Version of EBS-CSI driver"
}
