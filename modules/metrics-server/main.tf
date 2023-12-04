/**
 * # Installs metrics-server helm chart
 */

resource "helm_release" "metrics_server" {
  name       = var.name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "6.6.3"
  namespace  = "kube-system"

  values = [
    file("${path.module}/values.yaml")
  ]
}
