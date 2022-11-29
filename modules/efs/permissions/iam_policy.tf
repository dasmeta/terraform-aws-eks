resource "aws_iam_policy" "policy" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policy"
  path        = "/"
  description = "Policy for EFS and Kubernetes"

  policy = file("${path.module}/policies/iam_policy_efs.json")
}

resource "aws_iam_role" "role" {
  name                = format("%s-%s", "kube-efs-role", local.timestamp_sanitized)
  assume_role_policy  = file("${path.module}/policies//trusted_policy.json")
  managed_policy_arns = [aws_iam_policy.policy.arn]
}

locals {
  timestamp            = timestamp()
  timestamp_no_hyphens = replace("${local.timestamp}", "-", "")
  timestamp_no_spaces  = replace("${local.timestamp_no_hyphens}", " ", "")
  timestamp_no_t       = replace("${local.timestamp_no_spaces}", "T", "")
  timestamp_no_z       = replace("${local.timestamp_no_t}", "Z", "")
  timestamp_no_colons  = replace("${local.timestamp_no_z}", ":", "")
  timestamp_sanitized  = local.timestamp_no_colons
}
