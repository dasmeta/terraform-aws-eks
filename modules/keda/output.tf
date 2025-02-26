output "keda_iam_role_arn" {
  description = "IAM Role ARN for KEDA to access SQS"
  value       = aws_iam_role.keda-role.arn
}
