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
  default     = "8.3.9"
  description = "The app chart version to use"
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
  description = "Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/bitnami/external-dns?modal=values"
}
