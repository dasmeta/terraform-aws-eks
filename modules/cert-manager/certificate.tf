resource "kubectl_manifest" "certificate" {
  for_each = {
    for cert in var.certificates : "${cert.namespace}/${cert.name}" => cert
  }

  yaml_body = yamlencode(merge(
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = merge(
        {
          name      = each.value.name
          namespace = each.value.namespace
        },
        try(each.value.configs.metadata, {})
      )
      spec = local.certificate_specs["${each.value.namespace}/${each.value.name}"]
    },
    # Allow top-level configs override (excluding metadata and spec which are handled above)
    {
      for k, v in try(each.value.configs, {}) : k => v
      if k != "metadata" && k != "spec"
    }
  ))

  depends_on = [
    kubectl_manifest.cluster_issuer
  ]
}
