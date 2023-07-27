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
    name                       = string
    protocol_type              = string
    route_selection_expression = string
  }))
  default = ([
    {
      name                       = "api"
      protocol_type              = "WEBSOCKET"
      route_selection_expression = "$request.body.action"
    },
    {
      name                       = "api1"
      protocol_type              = "WEBSOCKET1"
      route_selection_expression = "$request.body.action1"
    }


  ])
}

variable "api_integrations" {
  default = []
  type    = list(string)
}

variable "api_stages" {
  default = []
  type    = list(string)
}

variable "api_vpc_links" {
  default = []
  type    = list(string)
}
