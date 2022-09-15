resource "helm_release" "nginx_ingress" {
  name = "weave-scope"

  # repository = "https://cloudnativeapp.github.io/charts/curated/"
  chart = "https://github.com/dasmeta/helm/tree/main/charts/base"

}
