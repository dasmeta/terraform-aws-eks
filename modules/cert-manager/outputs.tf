output "helm_release_name" {
  description = "Name of the cert-manager Helm release"
  value       = helm_release.cert-manager.name
}

output "helm_release_namespace" {
  description = "Namespace of the cert-manager Helm release"
  value       = helm_release.cert-manager.namespace
}

output "cluster_issuer_names" {
  description = "Map of ClusterIssuer names by issuer name"
  value = {
    for issuer in var.cluster_issuers : issuer.name => issuer.name
  }
}

output "iam_role_arn" {
  description = "ARN of the IAM role created for DNS01 (shared by all issuers, if enabled)"
  value       = try(module.dns01_role[0].iam_role_arn, null)
}

output "certificate_names" {
  description = "Map of certificate names by namespace/name"
  value = {
    for cert in var.certificates : "${cert.namespace}/${cert.name}" => cert.name
  }
}
