output "karpenter_data" {
  value       = module.this
  description = "Karpenter data"
}

output "helm_metadata" {
  value       = helm_release.this.metadata
  description = "Helm release metadata"
}

# The fully resolved NodePool specs, after preset defaults, per-pool overrides and requirement merging.
# Useful for seeing what a pool actually became without rendering the chart, and it is what the native tests
# assert against: the rendered helm values embed upstream module outputs and are therefore unknown at plan.
output "node_pools" {
  value       = local.nodePools
  description = "Resolved karpenter NodePool specifications, keyed by pool name"
}
