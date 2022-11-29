variable "efs_id" {
  description = "Id of EFS filesystem in AWS (Required)"
  type        = string
}

variable "cluster_oidc_arn" {
  description = "oidc arn of cluster"
  type        = string
}
