resource "helm_release" "weave-scope" {
  namespace        = var.namespace
  create_namespace = var.create_namespace
  name             = var.release_name
  chart            = "weave-scope"
  version          = "1.0.1"
  repository       = "https://dasmeta.github.io/helm/"
  reuse_values     = true
  values = [
    templatefile("${path.module}/resources/values.yaml.tpl",
      {
        config        = var.annotations
        service_type  = var.service_type
        ingress_host  = var.ingress_host
        ingress_name  = var.ingress_name
        ingress_class = var.ingress_class
    })
  ]
}
