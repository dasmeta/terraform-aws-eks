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

variable "APIs" {
  description = "API Gateway's API and its dependent parts configurations"
  type = list(object({
    name                         = string
    protocol_type                = string
    route_selection_expression   = optional(string)
    api_key_selection_expression = optional(string)
    credentials_arn              = optional(string)
    description                  = optional(string)
    disable_execute_api_endpoint = optional(bool)
    disable_schema_validation    = optional(bool)
    version                      = optional(string)
    tags                         = optional(map(string))


    integrations = list(object({
      integration_name              = string
      integration_type              = string
      connection_type               = optional(string)
      integration_uri               = string
      payload_format_version        = optional(string)
      template_selection_expression = optional(string)
      connection_type               = optional(string)
      connection_id                 = optional(string)
      description                   = optional(string)
      request_parameters            = optional(map(string))
      timeout_milliseconds          = optional(number)
      content_handling_strategy     = optional(string)
      credentials_arn               = optional(string)
      integration_method            = optional(string)
    }))

    routes = list(object({
      integration_name                    = string
      route_key                           = string
      api_key_required                    = optional(bool)
      authorization_type                  = optional(string)
      authorizer_id                       = optional(string)
      model_selection_expression          = optional(string)
      operation_name                      = optional(string)
      request_models                      = optional(map(string))
      request_parameters                  = optional(map(string))
      route_response_selection_expression = optional(string)
    }))


    stages = list(object({
      name                  = string
      description           = optional(string)
      client_certificate_id = optional(string)
      stage_variables       = optional(map(string))
      tags                  = optional(map(string))
    }))
  }))
}

variable "subnet_ids" {
  description = "EKS private Subnet IDs to pass inside module"
  type        = list(string)
}

variable "vpc_link_name" {
  description = "VPC link name"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC id, needed for vpc link"
  type        = string
}
