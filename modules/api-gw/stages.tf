resource "kubernetes_manifest" "stage" {
  for_each = { for api in flatten([for api in var.api_gateway_resources : api.stages]) : api.name => api }
  manifest = {
    apiVersion = "apigatewayv2.services.k8s.aws/v1alpha1"
    kind       = "Stage"
    metadata = {
      name      = each.value.name
      namespace = lookup(each.value, "namespace", "default")
    }
    spec = {
      apiRef = {
        from = {
          name = each.value.apiRef_name
        }
      }
      stageName   = each.value.stageName
      autoDeploy  = each.value.autoDeploy
      description = each.value.description
    }
  }
}
