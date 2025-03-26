resource "aws_iam_role" "keda-role" {
  name = "${var.eks_cluster_name}-${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn != null ? var.oidc_provider_arn : module.eks_data.oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "${local.account_id}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "keda_sqs_policy" {
  count = var.attach_policies.sqs ? 1 : 0

  name        = "${var.eks_cluster_name}-${var.name}-role-policy-sqs"
  description = "IAM policy for KEDA to read SQS messages"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:*",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_keda_sqs_policy" {
  count = var.attach_policies.sqs ? 1 : 0

  policy_arn = aws_iam_policy.keda_sqs_policy[0].arn
  role       = aws_iam_role.keda-role.name
}
