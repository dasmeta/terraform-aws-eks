variable "crds_create" {
  type        = bool
  default     = true
  description = "Whether to create linkerd crds"
}

variable "crds_chart_version" {
  type        = string
  default     = "1.8.0"
  description = "The app crds chart version"
}

variable "chart_version" {
  type        = string
  default     = "1.16.11" # we use an old/stable release version here, TODO: check possibility to upgrade to newer and stable version(which maybe can be found in edge releases) as this one seems got deprecated
  description = "The linkerd chart version"
}

variable "viz_create" {
  type        = bool
  default     = true
  description = "Whether to create linkerd viz dashboards"
}

variable "viz_chart_version" {
  type        = string
  default     = "30.12.11"
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

variable "configs_viz" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones for linkerd_viz. Check the helm chart available configs for specified var.viz_chart_version here: https://artifacthub.io/packages/helm/linkerd2/linkerd-viz"
}
