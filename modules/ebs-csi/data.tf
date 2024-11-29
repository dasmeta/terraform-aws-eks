data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_addon_version" "this" {
  count = var.addon_version == null ? 1 : 0

  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = var.most_recent
}
