output "iam_role_arn" {
  value = aws_iam_role.role.arn
}

output "iam_role_name" {
  value = aws_iam_role.role.name
}

output "iam_role_id" {
  value = aws_iam_role.role.id
}

output "iam_policy_arn" {
  value = aws_iam_policy.policy.arn
}

output "iam_policy_id" {
  value = aws_iam_policy.policy.id
}
