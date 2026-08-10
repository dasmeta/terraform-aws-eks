locals {
  # Kubernetes Service names the linkerd-control-plane chart hardcodes for
  # each admission webhook (fixed "linkerd-" prefix regardless of the Helm
  # release name - verified against the chart's own templates).
  webhook_services = {
    proxy_injector    = "linkerd-proxy-injector"
    profile_validator = "linkerd-sp-validator"
    policy_validator  = "linkerd-policy-validator"
  }
}

resource "tls_private_key" "webhook" {
  for_each = local.webhook_services

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Self-signed per-webhook server certificate. Each webhook's caBundle is set
# to its own crtPEM (see outputs.tf), matching the same self-signed shape
# Helm falls back to when no certs are provided - the only change is a long
# validity_period_hours instead of Helm's unrotated 1-year default.
resource "tls_self_signed_cert" "webhook" {
  for_each = local.webhook_services

  private_key_pem       = tls_private_key.webhook[each.key].private_key_pem
  validity_period_hours = var.validity_period_hours
  is_ca_certificate     = true

  subject {
    common_name = "${each.value}.${var.namespace}.svc"
  }

  # Multiple forms since the exact hostname the API server dials with (and
  # therefore validates the cert against) depends on cluster DNS config;
  # covering all of them avoids a SAN mismatch on any given cluster.
  dns_names = [
    each.value,
    "${each.value}.${var.namespace}",
    "${each.value}.${var.namespace}.svc",
    "${each.value}.${var.namespace}.svc.cluster.local",
  ]

  allowed_uses = [
    "crl_signing",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}
