variable "name" {
  type        = string
  default     = "metrics-server"
  description = "Metrics server name."
}

variable "chart_version" {
  type        = string
  default     = "7.2.16"
  description = "The app chart version"
}
