module "api-gw-controller" {
  source = "./modules/api-gw"

  count = var.enable_api_gw_controller ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  deploy_region    = var.api_gw_deploy_region
}
