variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn to pass to policy"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name to pass to role"
}

variable "chart_version" {
  description = "Chart version of api-gw"
  type        = string
  default     = "0.0.17"
}

variable "deploy_region" {
  description = "Region in which API gatewat will be configured"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "api_gateway_resources" {
  description = "Nested map containing API, Stage, and VPC Link resources"
  type = list(object({
    namespace = string
    api = object({
      name         = string
      protocolType = string
    })
    stages = optional(list(object({
      namespace   = string
      name        = string
      apiRef_name = string
      stageName   = string
      autoDeploy  = bool
      description = string
    })))
    vpc_links = optional(list(object({
      namespace = string
      name      = string
    })))
  }))
}
