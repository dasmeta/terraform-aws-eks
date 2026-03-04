# Create ClusterIssuer resources for each issuer
resource "kubectl_manifest" "cluster_issuer" {
  for_each = local.cluster_issuers_map

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = each.value.name
    }
    spec = {
      acme = {
        server = each.value.server
        email  = each.value.email
        privateKeySecretRef = {
          name = coalesce(each.value.private_key_secret_name, each.value.name)
        }
        solvers = local.cluster_issuer_solvers[each.value.name]
      }
    }
  })

  depends_on = [
    helm_release.cert-manager,
    kubectl_manifest.dns01_solver_secret
  ]
}
