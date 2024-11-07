resource "helm_release" "this" {
  name             = "flagger"
  repository       = "https://flagger.app"
  chart            = "flagger"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(var.configs)]
}
