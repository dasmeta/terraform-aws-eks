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

variable "api_gateway_resources" {
  description = "Nested map containing API, Stage, and VPC Link resources"
  type = list(object({
    api = object({
      name         = string
      protocolType = string
    })
    stages = list(object({
      name        = string
      apiRef_name = string
      stageName   = string
      autoDeploy  = bool
      description = string
    }))
    vpc_links = list(object({
      name             = string
      securityGroupIDs = list(string)
      subnetIDs        = list(string)
    }))
  }))
}
