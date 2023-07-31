resource "aws_apigatewayv2_integration" "example" {

  for_each = { for integration in local.integrations : integration.integration_name => integration }

  api_id                        = aws_apigatewayv2_api.api[each.value.api_name].id
  integration_type              = each.value.integration_type
  connection_type               = each.value.connection_type
  integration_uri               = each.value.integration_uri
  payload_format_version        = each.value.payload_format_version
  template_selection_expression = each.value.template_selection_expression
  connection_id                 = each.value.connection_id != null ? each.value.connection_id : aws_apigatewayv2_vpc_link.example.id
  description                   = each.value.description
  request_parameters            = each.value.request_parameters
  timeout_milliseconds          = each.value.timeout_milliseconds
  content_handling_strategy     = each.value.content_handling_strategy
  credentials_arn               = each.value.credentials_arn
  integration_method            = each.value.integration_method
  tls_config {
    server_name_to_verify = each.value.server_name_to_verify
  }
}

locals {
  integrations = flatten([
    for api in var.APIs : [

      for integration in api.integrations : {

        integration_name              = integration.integration_name
        api_name                      = api.name
        unique_id                     = ""
        integration_type              = integration.integration_type
        connection_type               = integration.connection_type
        integration_uri               = integration.integration_uri
        payload_format_version        = integration.payload_format_version
        template_selection_expression = integration.template_selection_expression
        connection_type               = integration.connection_type
        connection_id                 = integration.connection_id
        description                   = integration.description
        request_parameters            = integration.request_parameters
        timeout_milliseconds          = integration.timeout_milliseconds
        content_handling_strategy     = integration.content_handling_strategy
        credentials_arn               = integration.credentials_arn
        integration_method            = integration.integration_method
        server_name_to_verify         = integration.server_name_to_verify
      }
    ]
  ])
}
