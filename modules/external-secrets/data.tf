data "aws_caller_identity" "this" {}

# OIDC provider lookup is only needed for the IRSA attachment method and only when an ARN
# is not supplied explicitly.
data "aws_eks_cluster" "this" {
  count = local.use_service_account_annotation && var.resolve_oidc_from_cluster && var.oidc_provider_arn == null ? 1 : 0

  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  count = local.use_service_account_annotation && var.resolve_oidc_from_cluster && var.oidc_provider_arn == null ? 1 : 0

  url = data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

data "aws_region" "this" {
  count = var.region == null ? 1 : 0
}
