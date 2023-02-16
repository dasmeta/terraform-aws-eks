data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_eks_addon" "addons" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_version
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.role.name}"
}
