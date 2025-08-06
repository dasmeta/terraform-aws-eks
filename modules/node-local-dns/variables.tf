variable "name" {
  type        = string
  default     = "node-local-dns"
  description = "The name of helm release"
}

variable "namespace" {
  type        = string
  default     = "kube-system" # it is supposed local-dns service should be installed on kube-system namespace where core-dns/kube-dns service by default placed, so that do change the namespace if only core-dns/kube-dns is placed on another namespace
  description = "The namespace where the service will be installed"
}

variable "chart_version" {
  type        = string
  default     = "2.1.10"
  description = "The helm chart version to use"
}

variable "wait" {
  type        = bool
  default     = true
  description = "Whether to wait for helm chart to be successful deployed"
}

variable "core_dns_service_name" {
  type        = string
  default     = "kube-dns"
  description = "The name of core-dns/kube-dns service which will be used to auto-identify local-dns required config named dnsServer"
}

variable "configs" {
  type        = any
  default     = {}
  description = "The extra config values to pass to chart, for possible configs check: https://artifacthub.io/packages/helm/deliveryhero/node-local-dns/2.1.10?modal=values"
}
