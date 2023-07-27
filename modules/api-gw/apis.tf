resource "aws_apigatewayv2_api" "api" {
  for_each                   = toset(var.APIs)
  name                       = each.value.name
  protocol_type              = each.value.protocol_type
  route_selection_expression = each.value.route_selection_expression
}
