/**
 * ## Example
 * This is an example of usage `weave-scope` module
 *
 *
 * ```
 * module "weave-scope" {
 *   count            = var.weave_scope_enabled ? 1 : 0
 *   source           = "./modules/weave-scope"
 *
 *   namespace        = "Weave"
 *   create_namespace = true
 *   ingress_class = "nginx"
 *   ingress_host = "www.example.com"
 *   annotations = {
 *     "key1" = "value1"
 *     "key2" = "value2"
 *   }
 *   service_type = "NodePort"
 *
 * }
 *
 * provider "helm" {
 *   kubernetes {
 *     host                   = cluster.host
 *     cluster_ca_certificate = cluster.certificate
 *     token                  = cluster.token
 *   }
 * }
 * ```
 **/

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
        read_only     = var.read_only
    })
  ]
}
