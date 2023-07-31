resource "aws_apigatewayv2_stage" "example" {

  for_each = { for stage in local.stages : stage.api_name => stage }

  api_id                = aws_apigatewayv2_api.api[each.key].id
  name                  = each.value.name
  client_certificate_id = each.value.client_certificate_id
  description           = each.value.description
  tags                  = each.value.tags
}

locals {
  stages = flatten([
    for api in var.APIs : [

      for stage in api.stages : {

        api_name              = api.name
        name                  = stage.name
        client_certificate_id = stage.client_certificate_id
        description           = stage.description
        tags                  = stage.tags
      }
    ]
  ])
}
