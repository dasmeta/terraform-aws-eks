locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
  cluster_autoscaler_enabled  = var.autoscaling && !var.karpenter.enabled # We disable eks cluster autoscaler in case karpenter have been enabled as karpenter replaces cluster autoscaler and there are possibility of conflicts if both are enabled

  vpc_id     = var.vpc.create.name != null ? module.vpc[0].id : var.vpc.link.id
  subnet_ids = var.vpc.create.name != null ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids

  cluster_addons = { for key, value in merge(var.cluster_addons, var.default_addons) : key => merge(
    value,
    try(value.configuration_values, null) == null ? {} : { for key, value in(can(tostring(value.configuration_values)) ? { configuration_values = null } : { configuration_values = jsonencode(value.configuration_values) }) : key => value if value != null }
  ) }
}
