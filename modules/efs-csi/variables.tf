variable "efs_id" {
  description = "Id of EFS filesystem in AWS (Required)"
  type        = string
}

variable "cluster_oidc_arn" {
  description = "oidc arn of cluster"
  type        = string
}

variable "cluster_name" {
  description = "Parent cluster name"
  type        = string
}

variable "storage_class_name" {
  type        = string
  description = "Storage class name"
  default     = "efs-sc"
}

variable "service_account_name" {
  type        = string
  description = "Service account name"
  default     = "efs-csi-controller-sa"
}
