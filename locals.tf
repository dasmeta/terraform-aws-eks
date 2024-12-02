locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
  cluster_autoscaler_enabled  = var.autoscaling && !var.karpenter.enabled # We disable eks cluster autoscaler in case karpenter have been enabled as karpenter replaces cluster autoscaler and there are possibility of conflicts if both are enabled
}
