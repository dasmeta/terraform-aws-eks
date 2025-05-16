variable "name" {
  type        = string
  default     = "app-namespaces"
  description = "The helm release name"
}

variable "cluster_name" {
  type        = string
  description = "The eks cluster name"
}

variable "oidc_provider_arn" {
  description = "EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'."
  type        = string
}

variable "cluster_endpoint" {
  type        = string
  description = "The eks cluster endpoint"
}

variable "region" {
  type        = string
  default     = null
  description = "The aws region"
}

variable "chart_version" {
  type        = string
  default     = "0.1.0"
  description = "The app chart version"
}

variable "namespace" {
  description = "The namespace to install main helm."
  type        = string
  default     = "meta-system"
}

variable "create_namespace" {
  type        = bool
  default     = false
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
  type = object({
    list   = optional(list(string), []) # list of application namespaces to create/init with cluster creation
    labels = optional(any, {})          # map of key=>value strings to attach to namespaces
    dockerAuth = optional(object({      # docker hub image registry configs, this based external secrets operator(operator should be enabled). which will allow to create 'kubernetes.io/dockerconfigjson' type secrets in app(and also all other) namespaces and configure app namespaces to use this
      enabled                 = optional(bool, false)
      refreshTime             = optional(string, "3m")                                         # frequency to check filtered namespaces and create ExternalSecrets (and k8s secret)
      refreshInterval         = optional(string, "1h")                                         # frequency to pull/refresh data from aws secret
      name                    = optional(string, "docker-registry-auth")                       # the name to use when creating k8s resources
      secretManagerSecretName = optional(string, "account")                                    # aws secret manager secret name where dockerhub credentials placed, we use "account" default secret
      namespaceSelector       = optional(any, { matchLabels : { "docker-auth" = "enabled" } }) # namespaces selector expression, the app namespaces created here will have this selectors by default, but for other namespaces you may need to set labels manually. this can be set to empty object {} to create secrets in all namespaces
      registries = optional(list(object({                                                      # docker registry configs
        url         = optional(string, "https://index.docker.io/v1/")                          # docker registry server url
        usernameKey = optional(string, "DOCKER_HUB_USERNAME")                                  # the aws secret manager secret key where docker registry username placed
        passwordKey = optional(string, "DOCKER_HUB_PASSWORD")                                  # the aws secret manager secret key where docker registry password placed, NOTE: for dockerhub under this key should be set personal access token instead of standard ui/profile password
        authKey     = optional(string)                                                         # the aws secret manager secret key where docker registry auth placed
      })), [{ url = "https://index.docker.io/v1/", usernameKey = "DOCKER_HUB_USERNAME", passwordKey = "DOCKER_HUB_PASSWORD", authKey = null }])
    }), { enabled = false })
  })
  default     = {}
  description = "The main configurations"
}
