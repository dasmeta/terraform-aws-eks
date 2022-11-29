resource "aws_iam_policy" "policy" {
  #name        = format("%s-%s", "AmazonEKS_EFS_CSI_Driver_Policy", local.timestamp_sanitized)
  name        = "AmazonEKS_EFS_CSI_Driver_Policy"
  path        = "/"
  description = "Policy for EFS and Kubernetes"

  policy = file("${path.module}/policies/iam_policy_efs.json")
}

resource "aws_iam_role" "role" {
  #name                = format("%s-%s", "kube-efs-role", local.timestamp_sanitized)
  name = "kube-efs-role"
  assume_role_policy = templatefile("${path.module}/policies//trusted_policy.json", {
    oidc           = var.cluster_oidc_arn,
    current_region = data.aws_region.current.name,
  oidc_id = local.oidc_id })
  managed_policy_arns = [aws_iam_policy.policy.arn]
}

data "aws_region" "current" {}

locals {
  oidc_id = split("/", var.cluster_oidc_arn)[3]
}

#locals {
#  timestamp            = timestamp()
#  timestamp_no_hyphens = replace("${local.timestamp}", "-", "")
#  timestamp_no_spaces  = replace("${local.timestamp_no_hyphens}", " ", "")
#  timestamp_no_t       = replace("${local.timestamp_no_spaces}", "T", "")
#  timestamp_no_z       = replace("${local.timestamp_no_t}", "Z", "")
#  timestamp_no_colons  = replace("${local.timestamp_no_z}", ":", "")
#  timestamp_sanitized  = local.timestamp_no_colons
#}
