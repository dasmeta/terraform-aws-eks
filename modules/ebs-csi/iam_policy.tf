resource "aws_iam_role" "role" {
  name = "kube-ebs-role-${var.cluster_name}-${local.region}"
  assume_role_policy = templatefile("${path.module}/policies/trusted_policy.json", {
    oidc           = var.cluster_oidc_arn,
    current_region = local.region,
  oidc_id = local.oidc_id })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

locals {
  oidc_id = split("/", var.cluster_oidc_arn)[3]
}
