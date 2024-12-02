data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

data "aws_eks_addon_version" "this" {
  count = var.adot_version == null ? 1 : 0

  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = var.most_recent
}
