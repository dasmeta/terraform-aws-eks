variable "chart_version" {
  type        = string
  default     = "1.38.0"
  description = "The app chart version"
}

variable "metric_template_chart_version" {
  type        = string
  default     = "0.1.0"
  description = "The metric template chart version"
}

variable "namespace" {
  description = "The namespace to install main helm."
  type        = string
  default     = "ingress-nginx" # by default it uses nginx as provider so we install flagger in nginx ingress namespace as of doc
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create namespace if requested"
}

variable "atomic" {
  type        = bool
  default     = false
  description = "Whether use helm deploy with --atomic flag"
}

variable "wait" {
  type        = bool
  default     = true
  description = "Whether use helm deploy with --wait flag"
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/flagger/flagger?modal=values"
}

variable "enable_metric_template" {
  type        = bool
  default     = false
  description = "Whether to install flagger-metric-template helm"
}

variable "metric_template_configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/flagger-metric-template-0.1.0/charts/flagger-metric-template"
}

variable "enable_loadtester" {
  type        = bool
  default     = false
  description = "Whether to install loadtester helm"
}
