module "keda" {
  source = "./modules/keda"
  count  = var.keda.enabled ? 1 : 0

  account_id        = local.account_id
  oidc_provider_arn = module.eks-cluster[0].oidc_provider_arn
  name              = var.keda.name
  namespace         = var.keda.namespace
  create_namespace  = var.keda.create_namespace
  keda_version      = var.keda.keda_version
  attach_policies   = var.keda.attach_policies
  eks_cluster_name  = module.eks-cluster[0].cluster_name

  depends_on = [module.eks-core-components-and-alb]
}
