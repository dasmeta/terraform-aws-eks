/**
 * # Installs metrics-server helm chart
 */

resource "helm_release" "metrics_server" {
  name       = var.name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = var.chart_version
  namespace  = "kube-system"

  values = [
    file("${path.module}/values.yaml")
  ]
}
