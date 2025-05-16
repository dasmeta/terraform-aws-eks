module "iam_role_for_service_accounts_eks" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.55.0"

  role_name = "eks-s3-csi-${var.cluster_name}-${local.region}"

  attach_mountpoint_s3_csi_policy = true
  mountpoint_s3_csi_bucket_arns   = local.mountpoint_s3_csi_bucket_arns
  mountpoint_s3_csi_path_arns     = local.mountpoint_s3_csi_path_arns

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.serviceAccount}"]
    }
  }
}

resource "aws_eks_addon" "this" {
  cluster_name                = var.cluster_name
  addon_name                  = local.addon_name
  addon_version               = coalesce(var.addon_version, try(data.aws_eks_addon_version.this[0].version, null))
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.iam_role_for_service_accounts_eks.iam_role_arn
}
