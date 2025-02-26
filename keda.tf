module "keda" {
  source = "./modules/keda"
  count  = var.keda.enabled ? 1 : 0

  name             = var.keda.name
  namespace        = var.keda.namespace
  create_namespace = var.keda.create_namespace
  keda_version     = var.keda.keda_version
  eks_cluster_name = module.eks-cluster[0].cluster_name
}
