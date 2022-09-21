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

# variable "enabl_auth" {
#   type    = bool
#   default = true
# }

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "ingress_class" {
  type    = string
  default = "nginx"
}

variable "ingress_host" {
  type = string
}

variable "service_type" {
  type    = string
  default = "ClusterIP"
}
