resource "aws_eks_addon" "addons" {
  cluster_name                = var.cluster_name
  addon_name                  = local.addon_name
  addon_version               = coalesce(var.addon_version, try(data.aws_eks_addon_version.this[0].version, null))
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.role.name}"
}
