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
    jsonencode({
      # NOTE: we set/switch image repository related to change in bitnami to remove the original bitnami org/repository dockerhub repos and migrate all existing/old images to bitnamilegacy, for more info check https://github.com/bitnami/containers/issues/83267
      # TODO: consider a change to use another image repository which is maintained
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      image = {
        repository = "bitnamilegacy/kubernetes-event-exporter"
      }
    }),
    jsonencode(var.configs)
  ]
}
