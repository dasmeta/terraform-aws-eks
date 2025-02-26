variable "name" {
  description = "Name to deploy KEDA"
  type        = string
  default     = "keda"
}

variable "namespace" {
  description = "Namespace to deploy KEDA"
  type        = string
  default     = "keda"
}

variable "create_namespace" {
  description = "Create Namespace to deploy KEDA"
  type        = bool
  default     = true
}


variable "keda_version" {
  description = "Version of the KEDA Helm chart"
  type        = string
  default     = "2.16.1"
}

variable "chart_name" {
  description = "Chart name"
  type        = string
  default     = "keda"
}

variable "eks_cluster_name" {
  type        = string
  description = "Cluster name"
}
