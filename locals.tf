locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
}
