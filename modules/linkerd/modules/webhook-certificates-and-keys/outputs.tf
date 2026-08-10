# keyPEM uses private_key_pem_pkcs8 rather than private_key_pem on purpose. For
# ECDSA keys the tls provider emits private_key_pem in SEC1 encoding, which the
# policy controller cannot parse - it is Rust/rustls based and reads only PKCS#8
# or PKCS#1 RSA encoded keys, so it exits at startup with "failed to read TLS
# key: could not load private key" and takes the whole linkerd-destination pod
# into CrashLoopBackOff. The proxy-injector and sp-validator are Go based and
# accept either encoding, so PKCS#8 is used for all three to keep them
# consistent.
output "webhooks" {
  value = {
    proxyInjector = {
      crtPEM   = tls_self_signed_cert.webhook["proxy_injector"].cert_pem
      keyPEM   = tls_private_key.webhook["proxy_injector"].private_key_pem_pkcs8
      caBundle = tls_self_signed_cert.webhook["proxy_injector"].cert_pem
    }
    profileValidator = {
      crtPEM   = tls_self_signed_cert.webhook["profile_validator"].cert_pem
      keyPEM   = tls_private_key.webhook["profile_validator"].private_key_pem_pkcs8
      caBundle = tls_self_signed_cert.webhook["profile_validator"].cert_pem
    }
    policyValidator = {
      crtPEM   = tls_self_signed_cert.webhook["policy_validator"].cert_pem
      keyPEM   = tls_private_key.webhook["policy_validator"].private_key_pem_pkcs8
      caBundle = tls_self_signed_cert.webhook["policy_validator"].cert_pem
    }
  }
  description = "crtPEM/keyPEM/caBundle for each of linkerd-control-plane's admission webhooks (proxyInjector, profileValidator, policyValidator), matching the exact Helm values keys those need. Generated in Terraform with a long validity_period_hours so they don't silently expire the way the chart's own self-generated 1-year webhook certs do (those webhooks default to failurePolicy: Ignore, so an expired cert breaks proxy injection/validation with no visible error)."
  sensitive   = true
}
