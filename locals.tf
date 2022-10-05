locals {
  account_id = coalesce(var.account_id, data.aws_caller_identity.current.account_id)
  region     = coalesce(var.region, data.aws_region.current.name)

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, null), "/.*id//", "")
}
