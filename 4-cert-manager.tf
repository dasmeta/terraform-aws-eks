resource "helm_release" "cert-manager" {
  count = var.create_cert_manager ? 1 : var.metrics_exporter == "adot" ? 1 : 0

  namespace        = "cert-manager"
  create_namespace = true
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  atomic           = true
  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    module.eks-cluster
  ]
}
