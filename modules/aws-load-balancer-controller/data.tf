data "aws_eks_cluster" "this" {
  count = var.resolve_oidc_from_cluster && var.oidc_provider_arn == null ? 1 : 0

  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  count = var.resolve_oidc_from_cluster && var.oidc_provider_arn == null ? 1 : 0

  url = data.aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}
