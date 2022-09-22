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

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "ingress_class" {
  type    = string
  default = ""
}

variable "ingress_host" {
  type    = string
  default = ""
}

variable "service_type" {
  #Service type configuration (Valid attributes are "NodePort", "LoadBalancer", "ClusterIP")
  type    = string
  default = "ClusterIP"
  validation {
    condition     = contains(["NodePort", "LoadBalancer", "ClusterIP"], var.service_type)
    error_message = "The valid attributes are [NodePort], [LoadBalancer], [ClusterIP]"
  }
}
