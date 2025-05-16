resource "helm_release" "this" {
  name             = "kube-events-exporter"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "kubernetes-event-exporter"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = true
  wait             = false

  values = [
    jsonencode(var.configs)
  ]
}
