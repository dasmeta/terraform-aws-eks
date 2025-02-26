output "keda_iam_role_arn" {
  description = "IAM Role ARN for KEDA to access SQS"
  value       = module.keda.keda_iam_role_arn
}
