variable "chart_version" {
  type        = string
  default     = "3.5.3"
  description = "The app chart version to use"
}

variable "namespace" {
  description = "The namespace to install app helm."
  type        = string
  default     = "meta-system"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Create namespace if requested"
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/bitnami/kubernetes-event-exporter"
}
