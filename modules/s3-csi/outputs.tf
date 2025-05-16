output "addon_arn" {
  value       = aws_eks_addon.this.arn
  description = "The arn of installed/created addon"
}

output "role_arn" {
  value       = module.iam_role_for_service_accounts_eks.iam_role_arn
  description = "The arn of service account role"
}
