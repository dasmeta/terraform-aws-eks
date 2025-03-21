data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  count = var.get_oidc_provider_data ? 1 : 0

  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
