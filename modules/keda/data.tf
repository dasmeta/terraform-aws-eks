data "aws_caller_identity" "current" {
  count = var.account_id == null ? 1 : 0
}

module "eks_data" {
  source = "../eks-data"

  cluster_name           = var.eks_cluster_name
  get_oidc_provider_data = true
}

locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
}
