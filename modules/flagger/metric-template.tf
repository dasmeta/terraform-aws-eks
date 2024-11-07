resource "helm_release" "flagger_metric_template" {
  count = var.enable_metric_template ? 1 : 0

  name             = "flagger-metric-template"
  repository       = "https://dasmeta.github.io/helm"
  chart            = "flagger-metric-template"
  namespace        = var.namespace
  version          = var.metric_template_chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(var.metric_template_configs)]

  depends_on = [helm_release.this]
}
