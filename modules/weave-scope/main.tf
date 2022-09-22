resource "helm_release" "weave-scope" {
  namespace        = var.namespace
  create_namespace = var.create_namespace
  name             = var.release_name
  chart            = "weave-scope"
  repository       = "https://dasmeta.github.io/helm/"
  reuse_values     = true
  values = [
    templatefile("${path.module}/resources/values.yaml.tpl",
      {
        config       = var.annotations
        service_type = var.service_type
    })
  ]
}
