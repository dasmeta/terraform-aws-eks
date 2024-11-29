variable "namespace" {
  type        = string
  description = "The namespace of kubernetes resources"
  default     = "kube-system"
}

variable "chart_version" {
  type        = string
  default     = "0.10.7" # upgrade to >= 0.5.x requires some changes in base chart also where we use crd for defining secrets, look for detail https://external-secrets.io/v0.5.0/guides-v1beta1/
  description = "The app chart version to use"
}
