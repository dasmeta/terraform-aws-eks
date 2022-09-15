variable "namespace" {
  description = "Kubernetes namespace, in which Weave Scope will be deployed"
  type        = string
  default     = "meta-system"
}

variable "create_namespace" {
  description = "Weather create namespace or not"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm chart release name"
  type        = string
  default     = "weave-scope"
}
