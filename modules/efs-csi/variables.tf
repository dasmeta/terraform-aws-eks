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
  description = "Additional storage class configurations"
  type = list(object({
    name : string
    file_system_id : string
    directory_perms : string
    base_path : string
    uid : optional(number)
  }))
  default = []
}
