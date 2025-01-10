variable "name" {
  type        = string
  default     = "nginx"
  description = "Name"
}

variable "namespace" {
  type        = string
  default     = "ingress-nginx"
  description = "Namespace name"
}

variable "chart_version" {
  type        = string
  default     = "4.12.0"
  description = "The app chart version"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create namespace or use existing one"
}

variable "replicacount" {
  type        = number
  default     = 3
  description = "Nginx Ingress controller replica count"
}

variable "metrics_enabled" {
  type        = bool
  default     = true
  description = "Enable metric export"
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.12.0?modal=values"
}
