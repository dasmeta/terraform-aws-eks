
resource "aws_iam_policy" "this" {
  name        = local.iam_policy_name
  description = local.iam_policy_description
  policy      = file("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws-load-balancer-role" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.use_service_account_annotation ? [
        {
          Effect = "Allow"
          Principal = {
            Federated = local.oidc_provider_arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "oidc.eks.${var.region}.amazonaws.com/id/${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
              "oidc.eks.${var.region}.amazonaws.com/id/${local.oidc_provider_id}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            }
          }
        }
      ] : [],
      (local.create_pod_identity_association || local.create_external_pod_identity_role) ? [
        {
          Effect = "Allow"
          Principal = {
            Service = "pods.eks.amazonaws.com"
          }
          Action = [
            "sts:AssumeRole",
            "sts:TagSession"
          ]
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.aws-load-balancer-role.name
}

resource "aws_eks_pod_identity_association" "this" {
  count = local.create_pod_identity_association ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.aws-load-balancer-role.arn

  depends_on = [helm_release.aws-load-balancer-controller]
}
