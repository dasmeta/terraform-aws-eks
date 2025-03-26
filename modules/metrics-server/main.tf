/**
 * # Installs metrics-server helm chart
 */

resource "helm_release" "metrics_server" {
  name       = var.name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "metrics-server"
  version    = var.chart_version
  namespace  = "kube-system"

  values = [
    file("${path.module}/values.yaml")
  ]
}
