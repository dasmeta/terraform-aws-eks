resource "helm_release" "ingress-nginx" {
  name       = var.name
  repository = "https://kubernetes.github.io/ingress-nginx"
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      replicacount    = var.replicacount
      metrics_enabled = var.metrics_enabled
    })
  ]
  chart            = "ingress-nginx"
  namespace        = var.namespace
  create_namespace = true
}
