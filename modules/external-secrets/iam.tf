# Base IAM role for the external-secrets controller's service account. It carries no direct
# Secrets Manager access — it may only assume the per-store roles (role chaining), so each
# store keeps its own least-privilege, name-scoped access. No IAM users or static keys.
resource "aws_iam_role" "this" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.use_service_account_annotation ? [
        {
          Effect    = "Allow"
          Principal = { Federated = local.oidc_provider_arn }
          Action    = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
              "oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_provider_id}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            }
          }
        }
      ] : [],
      (local.create_pod_identity_association || local.create_external_pod_identity_role) ? [
        {
          Effect    = "Allow"
          Principal = { Service = "pods.eks.amazonaws.com" }
          Action    = ["sts:AssumeRole", "sts:TagSession"]
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy" "assume_store_roles" {
  name = "${local.iam_role_name}-assume-store-roles"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.store_role_arn_pattern
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "this" {
  count = local.create_pod_identity_association ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.this.arn

  depends_on = [helm_release.this]
}
