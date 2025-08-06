output "helm_metadata" {
  value       = helm_release.this.metadata
  description = "Helm release metadata"
}
