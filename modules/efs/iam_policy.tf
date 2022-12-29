resource "aws_iam_policy" "policy" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policy-${var.cluster_name}-${data.aws_region.current.name}"
  path        = "/"
  description = "Policy for EFS and Kubernetes"

  policy = file("${path.module}/policies/iam_policy_efs.json")
}

resource "aws_iam_role" "role" {
  name = "kube-efs-role-${var.cluster_name}-${data.aws_region.current.name}"
  assume_role_policy = templatefile("${path.module}/policies/trusted_policy.json", {
    oidc           = var.cluster_oidc_arn,
    current_region = data.aws_region.current.name,
  oidc_id = local.oidc_id })
  managed_policy_arns = [aws_iam_policy.policy.arn]
}

locals {
  oidc_id = split("/", var.cluster_oidc_arn)[3]
}
