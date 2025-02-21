output "karpenter_data" {
  value       = module.this
  description = "Karpenter data"
}

output "helm_metadata" {
  value       = helm_release.this.metadata
  description = "Helm release metadata"
}
