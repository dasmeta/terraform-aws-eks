variable "crds_create" {
  type        = bool
  default     = true
  description = "Whether to create linkerd crds"
}

variable "crds_chart_version" {
  type        = string
  default     = "2025.10.7"
  description = "The app crds chart version"
}

variable "chart_repository" {
  type        = string
  default     = "https://helm.linkerd.io/edge"
  description = "The Linkerd Helm chart repository to use for CRDs, control plane, and viz charts"
}

variable "chart_version" {
  type        = string
  default     = "2025.10.7"
  description = "The linkerd chart version"
}

variable "viz_create" {
  type        = bool
  default     = true
  description = "Whether to create linkerd viz dashboards"
}

variable "viz_chart_version" {
  type        = string
  default     = "2025.10.7"
  description = "The dashboard/monitoring chart version for linkerd"
}

variable "namespace" {
  description = "The namespace to install main helm."
  type        = string
  default     = "linkerd"
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

variable "resourcesDefaults" {
  type = any
  default = {
    cpu = {
      request = "100m"
    }
    memory = {
      request = "128Mi"
    }
  }
  description = "The default/shared container memory/cpu request/limits to use in all containers. For now we have only requests set to have minimal resources for services."
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones for linkerd. Check the helm chart available configs  here: https://artifacthub.io/packages/helm/linkerd2/linkerd2"
}

variable "configs_crds" {
  type        = any
  default     = {}
  description = "Configurations to pass and override defaults for the linkerd-crds Helm chart. The module defaults installGatewayAPI to true (the chart itself ships it as false); set installGatewayAPI = false here where another component already owns the Gateway API CRDs in the cluster."
}

variable "configs_viz" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones for linkerd_viz. Check the helm chart available configs for specified var.viz_chart_version here: https://artifacthub.io/packages/helm/linkerd2/linkerd-viz"
}
