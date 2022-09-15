resource "helm_release" "weave-scope" {
  namespace = var.namespace
  name      = "weave-scope"
  chart     = "https://github.com/dasmeta/helm/releases/download/weave-scope-1.0.0/weave-scope-1.0.0.tgz"
}
