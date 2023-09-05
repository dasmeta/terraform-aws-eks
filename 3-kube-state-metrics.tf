resource "helm_release" "kube-state-metrics" {
  count = var.enable_kube_state_metrics ? 1 : 0

  name             = "kube-state-metrics"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-state-metrics"
  namespace        = "kube-system"
  version          = "4.22.3"
  create_namespace = false
  atomic           = true
}
