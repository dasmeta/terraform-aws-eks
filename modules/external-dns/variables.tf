variable "cluster_name" {
  description = "K8s cluster name."
  type        = string
}

# the <oidc-id> can be found in the aws console eks details or iam identity providers pages
# TODO: implement to get this value inside the module also, so that no need to pass as variable
variable "oidc_provider_arn" {
  description = "EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'."
  type        = string
}

variable "chart_version" {
  type        = string
  default     = "1.20.0"
  description = "The external-dns chart version to use (see https://github.com/kubernetes-sigs/external-dns/releases)"
}

variable "chart_repository" {
  type        = string
  default     = "https://kubernetes-sigs.github.io/external-dns"
  description = "The external-dns chart repository to use"
}

variable "release_name" {
  type        = string
  default     = "external-dns"
  description = "The name of the external-dns Helm release"
}

variable "chart_name" {
  type        = string
  default     = "external-dns"
  description = "The name of the external-dns Helm chart"
}

variable "atomic" {
  type        = bool
  default     = true
  description = "Enable atomic Helm upgrades for the external-dns release"
}

variable "wait" {
  type        = bool
  default     = false
  description = "Whether to wait for external-dns Helm release to be deployed"
}

variable "namespace" {
  description = "The namespace to install external-dns helm."
  type        = string
  default     = "external-dns"
}

variable "service_account_name" {
  description = "The name of service-account to use for accessing aws resources."
  type        = string
  default     = "external-dns"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create namespace if requested"
}

variable "region" {
  type        = string
  default     = null
  description = "AWS Region, if not passed it will get region from terraform running current context"
}

variable "configs" {
  type        = any
  default     = {}
  description = "Configurations to pass and override default ones. See chart values: https://kubernetes-sigs.github.io/external-dns/latest/charts/external-dns/"
}
