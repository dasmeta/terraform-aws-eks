resource "aws_apigatewayv2_api" "api" {
  for_each                     = { for api in var.APIs : api.name => api }
  name                         = each.value.name
  protocol_type                = each.value.protocol_type
  route_selection_expression   = each.value.route_selection_expression
  api_key_selection_expression = each.value.api_key_selection_expression
  credentials_arn              = each.value.credentials_arn
  description                  = each.value.description
  disable_execute_api_endpoint = each.value.disable_execute_api_endpoint
  version                      = each.value.version
  tags                         = each.value.tags


  #route_selection_expression = each.value.route_selection_expression
}
