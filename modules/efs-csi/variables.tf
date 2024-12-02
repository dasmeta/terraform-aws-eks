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

variable "storage_classes" {
  description = "Additional storage class configurations: by default, 2 storage classes are created - efs-sc and efs-sc-root which has 0 uid. One can add another storage classes besides these 2."
  type = list(object({
    name : string
    provisioning_mode : optional(string, "efs-ap")
    file_system_id : string
    directory_perms : optional(string, "755")
    base_path : optional(string, "/")
    uid : optional(number)
  }))
  default = []
}

variable "chart_version" {
  type        = string
  default     = "3.0.8"
  description = "The app chart version"
}
