output "role_arn" {
  value       = module.role.arn
  description = "Created iam role arn, which was used for attaching to service account"
}

output "helm_metadata" {
  value       = helm_release.this.metadata
  description = "Helm release metadata"
}
