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

resource "aws_iam_policy" "adot" {
  name        = "adot_policy"
  path        = "/"
  description = "Adot Policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
          "ssm:GetParameters"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  count = length(local.adot_policies)

  policy_arn = local.adot_policies[count.index]
  role       = aws_iam_role.adot_collector.name

  depends_on = [
    aws_iam_policy.adot
  ]
}
