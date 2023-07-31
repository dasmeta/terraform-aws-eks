resource "kubernetes_manifest" "stage" {
  for_each = { for index, api in var.api_gateway_resources : index => api }
  dynamic "manifest" {
    for_each = each.value.stages
    content = {
      apiVersion = "apigatewayv2.services.k8s.aws/v1alpha1"
      kind       = "Stage"
      metadata = {
        name = manifest.value.name
      }
      spec = {
        apiRef = {
          from = {
            name = manifest.value.apiRef_name
          }
        }
        stageName   = manifest.value.stageName
        autoDeploy  = manifest.value.autoDeploy
        description = manifest.value.description
      }
    }
  }
}
