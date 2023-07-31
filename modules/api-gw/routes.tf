resource "aws_apigatewayv2_route" "example" {

  for_each = { for route in local.routes : route.api_name => route }

  api_id                              = aws_apigatewayv2_api.api[each.key].id
  route_key                           = each.value.route_key
  target                              = aws_apigatewayv2_integration.example[each.key].id
  api_key_required                    = each.value.api_key_required
  authorization_scope                 = each.value.authorization_scope
  authorization_type                  = each.value.authorization_type
  authorizer_id                       = each.value.authorizer_id
  model_selection_expression          = each.value.model_selection_expression
  operation_name                      = each.value.operation_name
  route_response_selection_expression = each.value.route_response_selection_expression
}

locals {
  routes = flatten([
    for api in var.APIs : [

      for route in api.routes : {

        api_name                            = api.name
        route_key                           = route.route_key
        api_key_required                    = route.api_key_required
        authorization_scope                 = route.authorization_scope
        authorization_type                  = route.authorization_type
        authorizer_id                       = route.authorizer_id
        model_selection_expression          = route.model_selection_expression
        operation_name                      = route.operation_name
        route_response_selection_expression = route.route_response_selection_expression
      }
    ]
  ])
}
