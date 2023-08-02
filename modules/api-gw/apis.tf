resource "kubernetes_manifest" "api" {
  for_each = { for index, api in var.api_gateway_resources : index => api }
  manifest = {
    apiVersion = "apigatewayv2.services.k8s.aws/v1alpha1"
    kind       = "API"
    metadata = {
      name      = each.value.api.name
      namespace = each.value.namespace
    }
    spec = {
      name         = each.value.api.name
      protocolType = each.value.api.protocolType
    }
  }
}
