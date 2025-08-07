variable "chart_version" {
  type        = string
  default     = "2.3.14"
  description = "The app chart version to use"
}

variable "configs" {
  type = any
  default = {
    settings = {
      prometheus_port = 20257
    }
    annotations = {
      "prometheus.io/scrape" = "true" # have annotation on pods to enable prometheus annotation based scrapping of node-problem-detector findings to see/use them in grafana
      "prometheus.io/port"   = "20257"
    }
  }
  description = "Configurations to pass to underlying helm chart"
}
