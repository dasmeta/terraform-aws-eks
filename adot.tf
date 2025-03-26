module "adot" {
  source = "./modules/adot"

  count = var.metrics_exporter == "adot" ? 1 : 0

  cluster_name                = var.cluster_name
  cluster_version             = var.cluster_version
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  adot_config                 = var.adot_config
  adot_version                = var.adot_version
  prometheus_metrics          = var.prometheus_metrics
  region                      = local.region
  depends_on = [
    module.eks-core-components,
    helm_release.cert-manager,
    kubernetes_namespace.meta-system
  ]
}
