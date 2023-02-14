data "aws_region" "current" {}

data "aws_caller_identity" "this" {}

resource "aws_iam_policy" "policy" {
  name        = "AmazonEKSClusterAutoscalerPolicy"
  path        = "/"
  description = "Amazon EKS Autoscaler Policy"

  policy = templatefile("${path.module}/policies/cluster-autoscaler-policy.json", {
    cluster_name = var.cluster_name
  })
}

resource "aws_iam_role" "role" {
  name = "cluster-autoscaler-${var.cluster_name}-${data.aws_region.current.name}"
  assume_role_policy = templatefile("${path.module}/policies/trusted-policy.json", {
    oidc           = var.cluster_oidc_arn,
    current_region = data.aws_region.current.name,
  oidc_id = local.oidc_id })
  managed_policy_arns = [aws_iam_policy.policy.arn]
}

locals {
  oidc_id = split("/", var.cluster_oidc_arn)[3]
}
