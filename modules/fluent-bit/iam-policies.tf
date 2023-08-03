resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-fluent-bit"
  description = "Permissions that are required to manage AWS cloudwatch metrics by fluent bit"

  policy = var.s3_permission ? file("${path.module}/iam-policy-s3-cloudwatch.json") : file("${path.module}/iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.fluent-bit.name
}
