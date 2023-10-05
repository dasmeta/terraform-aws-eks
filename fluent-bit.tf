module "fluent-bit" {
  source = "./modules/fluent-bit"

  count = var.create ? 1 : 0

  account_id = local.account_id
  region     = local.region

  cluster_name                = module.eks-cluster[0].cluster_id
  eks_oidc_root_ca_thumbprint = module.eks-cluster[0].eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn

  fluent_bit_name       = var.fluent_bit_name != "" ? var.fluent_bit_name : "${module.eks-cluster[0].cluster_id}-fluent-bit"
  log_group_name        = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch-${module.eks-cluster[0].cluster_id}"
  system_log_group_name = var.system_log_group_name
  log_retention_days    = var.log_retention_days

  values_yaml            = var.values_yaml
  drop_namespaces        = var.drop_namespaces
  log_filters            = var.log_filters
  additional_log_filters = var.additional_log_filters
}
