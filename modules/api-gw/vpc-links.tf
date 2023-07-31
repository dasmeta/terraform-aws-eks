resource "kubernetes_manifest" "vpc_link" {
  for_each = { for index, api in var.api_gateway_resources : index => api }
  dynamic "manifest" {
    for_each = each.value.vpc_links
    content = {
      apiVersion = "apigatewayv2.services.k8s.aws/v1alpha1"
      kind       = "VPCLink"
      metadata = {
        name = manifest.value.name
      }
      spec = {
        name             = manifest.value.name
        securityGroupIDs = manifest.value.securityGroupIDs
        subnetIDs        = manifest.value.subnetIDs
      }
    }
  }
}
