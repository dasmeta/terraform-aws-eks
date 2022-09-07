module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster.oidc_provider_arn
  cluster_name                = module.eks-cluster.cluster_id
}
