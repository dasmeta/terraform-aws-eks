resource "aws_iam_role" "keda-role" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "${data.aws_caller_identity.current.account_id}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "keda_sqs_policy" {
  count = var.attach_policies.sqs ? 1 : 0

  name        = "${var.name}-role-policy-sqs"
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
