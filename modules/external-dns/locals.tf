data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

locals {
  region        = coalesce(var.region, try(data.aws_region.current[0].name, null))
  oidc_provider = regex("^arn:aws:iam::[0-9]+:oidc-provider/(.*)$", var.oidc_provider_arn)[0]

  external_dns_sources = concat(
    ["service", "ingress"],
    var.enable_gateway_api_sources ? ["gateway-httproute", "gateway-grpcroute"] : []
  )
}
