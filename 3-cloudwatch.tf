module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  count = var.metrics_exporter == "cloudwatch" ? 1 : 0

  account_id = local.account_id
  region     = local.region

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  cluster_name                = module.eks-cluster[0].cluster_id
}
