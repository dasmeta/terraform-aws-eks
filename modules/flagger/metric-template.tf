resource "helm_release" "flagger_metrics_and_alerts" {
  count = var.metrics_and_alerts_configs != {} ? 1 : 0

  name             = "flagger-metrics-and-alerts"
  repository       = "https://dasmeta.github.io/helm"
  chart            = "flagger-metrics-and-alerts"
  namespace        = var.namespace
  version          = var.metric_template_chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(var.metrics_and_alerts_configs)]

  depends_on = [helm_release.this]
}
