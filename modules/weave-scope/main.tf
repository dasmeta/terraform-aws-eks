resource "helm_release" "weave-scope" {
  namespace        = var.namespace
  create_namespace = var.create_namespace
  name             = var.release_name
  chart            = "weave-scope"
  repository       = "https://dasmeta.github.io/helm/"

  set {
    name  = "global.service.type"
    value = var.service_type
  }
}
