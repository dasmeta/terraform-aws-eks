module "adot" {
  source = "./modules/adot"

  count = var.metrics_exporter == "adot" ? 1 : 0

  cluster_name                = var.cluster_name
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  adot_config                 = var.adot_config
  # resources_limit_cpu         = var.adot_config.resources.limit["cpu"]
  # resources_limit_memory      = var.adot_config.resources.limit["memory"]
  # resources_requests_cpu      = var.adot_config.resources.requests["cpu"]
  # resources_requests_memory   = var.adot_config.resources.requests["memory"]
  adot_version       = var.adot_version
  prometheus_metrics = var.prometheus_metrics
  region             = local.region
  depends_on = [
    module.eks-cluster,
    helm_release.cert-manager,
    kubernetes_namespace.meta-system
  ]
}
