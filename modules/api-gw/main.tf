resource "helm_release" "api-gw-release" {
  depends_on = [kubernetes_service_account.servciceaccount]

  name       = "api-gateway-controller"
  repository = "oci://public.ecr.aws/aws-controllers-k8s"
  chart      = "apigatewayv2-chart"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "aws.region"
    value = var.deploy_region == "" ? data.aws_region.current.name : var.deploy_region
  }
}
