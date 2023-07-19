resource "helm_release" "api-gw-release" {
  name       = "api-gateway-controller"
  repository = "oci://public.ecr.aws/aws-controllers-k8s"
  chart      = "apigatewayv2-chart"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

}
