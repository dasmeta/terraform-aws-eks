output "iam_policy_arn" {
  description = "The IAM policy ARN used by the controller role."
  value       = aws_iam_policy.this.arn
}

output "iam_role_arn" {
  description = "The IAM role ARN used by the controller."
  value       = aws_iam_role.aws-load-balancer-role.arn
}

output "iam_role_name" {
  description = "The IAM role name used by the controller."
  value       = aws_iam_role.aws-load-balancer-role.name
}

output "pod_identity_association_id" {
  description = "The EKS Pod Identity association ID when iam.attachment_method is pod_identity_association."
  value       = try(aws_eks_pod_identity_association.this[0].association_id, null)
}
