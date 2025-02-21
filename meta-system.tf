resource "kubernetes_namespace" "meta-system" {
  metadata {
    name = "meta-system"
  }

  depends_on = [
    module.eks-cluster
  ]
}
