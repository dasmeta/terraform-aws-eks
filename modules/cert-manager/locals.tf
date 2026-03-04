
locals {
  # Create a map of cluster issuers keyed by name for easier iteration
  cluster_issuers_map = {
    for issuer in var.cluster_issuers : issuer.name => issuer
  }

  # Build solvers for each issuer
  cluster_issuer_solvers = {
    for issuer in var.cluster_issuers : issuer.name => concat(
      try(issuer.dns01.enabled, false) && issuer.dns01 != null ? [{
        dns01 = issuer.dns01.configs
      }] : [],
      try(issuer.http01.enabled, false) && issuer.http01 != null ? [{
        http01 = issuer.http01.gateway_http_route != null ? {
          gatewayHTTPRoute = {
            parentRefs = [
              for ref in issuer.http01.gateway_http_route.parent_refs : {
                name      = ref.name
                namespace = ref.namespace
                kind      = ref.kind
                group     = ref.group
              }
            ]
          }
          } : issuer.http01.ingress != null ? {
          ingress = {
            class = issuer.http01.ingress.class
          }
        } : {}
      }] : []
    )
  }

  certificate_specs = {
    for cert in var.certificates : "${cert.namespace}/${cert.name}" => merge(
      {
        secretName = coalesce(cert.secret_name, cert.name)
        issuerRef = {
          name  = cert.issuer_ref.name
          kind  = cert.issuer_ref.kind
          group = cert.issuer_ref.group
        }
      },
      length(cert.dns_names) > 0 ? { dnsNames = cert.dns_names } : {},
      cert.common_name != null ? { commonName = cert.common_name } : {},
      cert.duration != null ? { duration = cert.duration } : {},
      cert.renew_before != null ? { renewBefore = cert.renew_before } : {},
      length(cert.usages) > 0 ? { usages = cert.usages } : {},
      try(cert.configs.spec, {})
    )
  }

  # Filter issuers that need DNS01 IAM roles
  issuers_with_dns01_iam = {
    for issuer in var.cluster_issuers : issuer.name => issuer
    if try(issuer.dns01.enabled, false) && issuer.dns01 != null && try(issuer.dns01.iam_role.enabled, false) && issuer.dns01.iam_role != null
  }

  # Collect all hosted zone ARNs from all issuers (union of all zones)
  all_hosted_zone_arns = distinct(flatten([
    for issuer in local.issuers_with_dns01_iam : length(try(issuer.dns01.iam_role.hosted_zone_arns, [])) > 0 ? issuer.dns01.iam_role.hosted_zone_arns : []
  ]))

  # DNS01 secret metadata only (names, no sensitive data) - safe for for_each.
  dns01_secret_meta = flatten([
    for issuer in var.cluster_issuers : [
      for ref in try(issuer.dns01.secret_refs, []) : {
        key       = "${issuer.name}/${ref.name}"
        name      = "${issuer.name}-${ref.name}"
        namespace = var.namespace
      }
    ] if try(issuer.dns01.enabled, false) && issuer.dns01 != null && length(try(issuer.dns01.secret_refs, [])) > 0
  ])
}
