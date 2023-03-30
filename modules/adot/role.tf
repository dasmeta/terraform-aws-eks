resource "aws_iam_role" "adot_collector" {
  name = "${var.cluster_name}-adot_collector"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider}:aud": "sts.amazonaws.com",
          "${local.oidc_provider}:sub": "system:serviceaccount:${var.namespace}:${local.service_account_name}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  for_each   = toset(var.adot_collector_policy_arns)
  policy_arn = each.key
  role       = aws_iam_role.adot_collector.name
}
