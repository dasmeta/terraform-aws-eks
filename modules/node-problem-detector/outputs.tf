output "helm_metadata" {
  value       = helm_release.node-problem-detector.metadata
  description = "Helm release metadata"
}
