data "aws_region" "current" {}

resource "aws_eks_addon" "addons" {
  cluster_name      = var.cluster_name
  addon_name        = "aws-ebs-csi-driver"
  addon_version     = "v1.15.0-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
}
