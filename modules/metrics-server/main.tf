/**
 * # Installs metrics-server helm chart
 */

resource "helm_release" "metrics_server" {
  name       = var.name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metrics-server"
  version    = "6.2.9"
  namespace  = "kube-system"

  values = [
    file("${path.module}/values.yaml")
  ]
}
