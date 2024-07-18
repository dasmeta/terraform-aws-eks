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
