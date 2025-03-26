variable "namespace" {
  type        = string
  description = "The namespace of kubernetes resources"
  default     = "kube-system"
}

variable "chart_version" {
  type        = string
  default     = "0.15.0"
  description = "The app chart version to use"
}
