data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

data "aws_eks_addon_version" "this" {
  count = var.addon_version == null ? 1 : 0

  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = var.most_recent
}

data "aws_s3_bucket" "this" {
  count = length(var.s3_buckets)

  bucket = var.s3_buckets[count.index]
}
