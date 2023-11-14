variable "host" {
  description = "Ingress host name"
  type        = string
  default     = "portainer.dasmeta.com"
}

variable "enable_ingress" {
  description = "Weather create ingress or not in k8s"
  type        = bool
  default     = true
}
