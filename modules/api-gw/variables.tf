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


    stages = list(object({
      name                  = string
      description           = optional(string)
      client_certificate_id = optional(string)
      stage_variables       = optional(map(string))
      tags                  = optional(map(string))
    }))
  }))
  #  default = ([
  #    {
  #      name                       = "api"
  #      protocol_type              = "HTTP"
  #      #route_selection_expression = "$request.body.action"
  #
  #
  #      integrations = [{
  #        integration_type = "HTTP_PROXY"
  #        connection_type  = "VPC_LINK"
  #
  #        #integration_uri = "https://api.dev.ben-energy.com/api/users"
  #        integration_uri = "arn:aws:elasticloadbalancing:eu-central-1:093655346463:listener/app/dev-api-alb/bc5f120e99351ead/eaa8af133345fc8f"
  #      }]
  #
  #
  #      stages = [{
  #        name = "stage1"
  #      }]
  #    }
  #  ])
}

variable "subnet_ids" {
  type = list(string)
}

variable "name" {
  default = "vpc-link"
  type    = string
}

variable "vpc_id" {
  type = string
}
