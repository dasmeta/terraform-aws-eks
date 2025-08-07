resource "kubernetes_namespace" "meta-system" {
  metadata {
    name = local.meta_system_namespace
  }

  depends_on = [module.eks-core-components]
}
