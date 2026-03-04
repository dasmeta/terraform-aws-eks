variable "chart_version" {
  type        = string
  default     = "1.16.5"
  description = "The cert-manager helm chart version"
}

variable "namespace" {
  type        = string
  default     = "cert-manager"
  description = "Namespace where cert-manager will be installed"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create the namespace"
}

variable "atomic" {
  type        = bool
  default     = true
  description = "Whether to auto rollback if helm install fails"
}

variable "configs" {
  type = object({
    installCRDs = optional(bool, true)
  })
  default     = {}
  description = "Default Helm values to merge with the default cert-manager chart values"
}

variable "extra_configs" {
  type        = any
  default     = {}
  description = "Extra Helm values to merge with the default cert-manager chart values (e.g., controller config, webhook config)"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name for IAM role naming and IRSA trust policy"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN for IAM role trust policy"
}

variable "cluster_issuers" {
  type = list(object({
    name                    = optional(string, "letsencrypt-prod")                               # Name of the ClusterIssuer resource
    email                   = optional(string, "support@dasmeta.com")                            # Required - email for Let's Encrypt account registration
    server                  = optional(string, "https://acme-v02.api.letsencrypt.org/directory") # ACME server URL
    private_key_secret_name = optional(string, null)                                             # Optional: custom secret name for private key, defaults to cluster_issuer.name
    # For Route53 in the same AWS account we create the IAM role (iam_role below). For other providers (e.g. Cloudflare) use secret_refs + dns01_secret_data and configs.
    dns01 = optional(object({
      enabled = optional(bool, false) # Enable DNS01 challenge solver
      configs = optional(any, {})     # DNS01 solver configuration (e.g., secretRef for Cloudflare: apiTokenSecretRef.name = "${issuer.name}-<secret.name>")
      # Optional: create Kubernetes secrets for the solver. List only names here (no sensitive data). Pass actual data via the separate dns01_secret_data variable. Created secret name = "${issuer.name}-${ref.name}".
      secret_refs = optional(list(object({
        name = string # Final secret name will be "${cluster_issuer.name}-${name}"
      })), [])
      iam_role = optional(object({
        enabled          = optional(bool, true)       # Enable IAM role for DNS01 (IRSA) - uses cert-manager service account from Helm chart
        hosted_zone_arns = optional(list(string), []) # Optional: restrict to specific hosted zones, empty list = all zones
      }), {})
    }), null)
    http01 = optional(object({
      enabled = optional(bool, false) # Enable HTTP01 challenge solver
      gateway_http_route = optional(object({
        parent_refs = optional(list(object({
          name      = string                                        # Gateway name
          namespace = optional(string, "istio-system")              # Gateway namespace
          kind      = optional(string, "Gateway")                   # Gateway kind
          group     = optional(string, "gateway.networking.k8s.io") # Gateway API group
        })), [])
      }), null) # Gateway API HTTP01 configuration
      ingress = optional(object({
        class = optional(string, "nginx") # Ingress class for HTTP01
      }), null)                           # Traditional Ingress HTTP01 configuration
    }), null)
  }))
  default     = []
  description = "List of ClusterIssuer configurations. Supports multiple issuers. Each issuer supports DNS01 and HTTP01 challenge solvers. For HTTP01, can use Gateway API (gateway_http_route) or traditional Ingress (ingress)."
}

# Secret data for DNS01 solver secrets keyed by \"${issuer.name}/${secret_ref.name}\". Use this (e.g. from a sensitive variable) so for_each is not sensitive. Example: { \"letsencrypt-prod/cloudflare-api\" = { \"api-token\" = var.cloudflare_api_token } }
variable "dns01_secret_data" {
  type        = map(map(string))
  default     = {}
  sensitive   = true
  description = "Map of DNS01 secret data keyed by issuer name + secret name (e.g. \"letsencrypt-prod/cloudflare-api\"). Keeps sensitive data out of for_each."
}

variable "certificates" {
  type = list(object({
    name        = string
    namespace   = optional(string, "istio-system")
    secret_name = optional(string, null) # Optional: Kubernetes secret name for the issued cert; default is certificate name
    issuer_ref = object({
      name  = string
      kind  = optional(string, "ClusterIssuer")
      group = optional(string, "cert-manager.io")
    })
    dns_names    = optional(list(string), [])
    common_name  = optional(string, null)
    duration     = optional(string, null)     # e.g., "2160h" (90 days)
    renew_before = optional(string, null)     # e.g., "360h" (15 days)
    usages       = optional(list(string), []) # e.g., ["server auth", "client auth"]
    configs      = optional(any, {})          # Extra configs to merge into the Certificate spec
  }))
  default     = []
  description = "List of Certificate resources to create. Each object defines a cert-manager.io/v1 Certificate."
}
