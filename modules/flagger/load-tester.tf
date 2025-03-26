resource "helm_release" "flagger_loadtester" {
  count = var.enable_loadtester ? 1 : 0

  name             = "flagger-loadtester"
  repository       = "https://flagger.app"
  chart            = "loadtester"
  namespace        = var.namespace
  version          = var.load_tester_chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  depends_on = [helm_release.this]
}
