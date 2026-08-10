output "controller_role_arn" {
  description = "ARN of the controller's base IAM role; per-store roles trust this principal."
  value       = aws_iam_role.this.arn
}

output "service_account" {
  description = "Service account the controller runs as."
  value       = var.service_account_name
}

output "namespace" {
  description = "Namespace the controller is installed into."
  value       = var.namespace
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}
