# Create Kubernetes secrets for DNS01 solvers (e.g. Cloudflare API token). Reference in cluster_issuers[].dns01.configs (e.g. apiTokenSecretRef.name = "<issuer.name>-<secret.name>").
# for_each uses metadata only (no sensitive data); secret data is looked up by key to avoid sensitive values in loop context.
resource "kubectl_manifest" "dns01_solver_secret" {
  for_each = { for m in local.dns01_secret_meta : m.key => m }

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace
    }
    type = "Opaque"
    data = { for k, v in var.dns01_secret_data[each.key] : k => base64encode(v) }
  })

  depends_on = [helm_release.cert-manager]
}
