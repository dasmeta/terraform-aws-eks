variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn to pass to policy"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name to pass to role"
}

variable "limits" {
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "600Mi"
  }
}

variable "requests" {
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "600Mi"
  }
}

variable "eks_version" {
  type        = string
  default     = "1.32"
  description = "The version of eks cluster"
}

variable "autoscaler_image_patch" {
  type        = number
  description = "The patch number of autoscaler image"
  default     = 0
}

variable "scale_down_unneeded_time" {
  type        = number
  description = "Scale down unneeded in minutes"
  default     = 2
}
