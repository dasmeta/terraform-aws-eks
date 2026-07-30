variable "cluster_name" {
  type        = string
  description = "EKS cluster name (used for the Pod Identity association and OIDC lookup)."
}

variable "region" {
  type        = string
  default     = ""
  description = "AWS region of the cluster; used to build the OIDC issuer host for the IRSA trust policy."
}

variable "release_name" {
  type        = string
  default     = "external-secrets"
  description = "Helm release name."
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace to install the external-secrets controller into."
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Whether to create the namespace."
}

variable "service_account_name" {
  type        = string
  default     = "external-secrets"
  description = "Service account name the controller runs as. Must match what the association/IRSA binds to."
}

# Chart source: `name` holds EITHER a chart name (resolved against `repository`) OR a full
# https .tgz URL (a direct compressed endpoint, e.g. a privately-hosted archive). When a
# URL is given, `repository`/`version` are ignored (the archive is self-describing).
variable "chart" {
  type = object({
    name       = optional(string, "external-secrets")                   # chart name OR a full https .tgz URL (direct compressed endpoint)
    repository = optional(string, "https://charts.external-secrets.io") # helm repo URL; ignored when `name` is a .tgz URL
    version    = optional(string, "2.8.0")                              # chart version; ignored when `name` is a .tgz URL (2.8.0 ships the external-secrets.io/v1 API)
  })
  default = {}
}

# Container image overrides for the controller / webhook / cert-controller. Left unset, the
# chart's own defaults apply. `registry` is prepended to `repository` to form the full image
# path (e.g. a private registry mirror).
variable "image" {
  type = object({
    registry   = optional(string) # image registry host to prepend (e.g. a private registry); unset keeps the chart default
    repository = optional(string) # image repository path (without registry host); unset keeps the chart default
    tag        = optional(string) # image tag; unset keeps the chart default (chart appVersion)
  })
  default = {}
}

variable "values" {
  type        = any
  default     = {}
  description = "Default Helm values map for the release."
}

variable "extra_values" {
  type        = any
  default     = {}
  description = "Arbitrary extra Helm values merged last (highest precedence)."
}

variable "install_crds" {
  type        = bool
  default     = true
  description = "Whether the chart installs the external-secrets CRDs."
}

variable "atomic" {
  type    = bool
  default = false
}

variable "wait" {
  type    = bool
  default = true
}

variable "timeout" {
  type    = number
  default = 300
}

# --- AWS identity for the controller --------------------------------------------------------
# Pod Identity (preferred) or IRSA. No static IAM users/keys are ever created.
variable "attachment_method" {
  type        = string
  default     = "pod_identity_association"
  description = "How the controller SA gets its IAM role: pod_identity_association, service_account_role_annotation (IRSA), or null to manage the association externally."

  validation {
    condition     = contains(["pod_identity_association", "service_account_role_annotation", null], var.attachment_method)
    error_message = "attachment_method must be pod_identity_association, service_account_role_annotation, or null."
  }
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "OIDC provider ARN for the IRSA trust policy. If null and resolve_oidc_from_cluster is true, resolved from the cluster."
}

variable "resolve_oidc_from_cluster" {
  type        = bool
  default     = true
  description = "Look up the OIDC provider from the EKS cluster when oidc_provider_arn is not supplied (IRSA only)."
}

variable "iam_role_name" {
  type        = string
  default     = null
  description = "Optional name override for the controller IAM role. Defaults to external-secrets-<cluster_name>."
}

variable "store_role_name_prefix" {
  type        = string
  default     = "external-secrets-store-"
  description = "Naming prefix for per-store IAM roles. The controller is granted sts:AssumeRole on roles matching this prefix (role chaining), so it must match the store module's role naming."
}
