
output "identity" {
  value = {
    trustAnchorsPEM = tls_self_signed_cert.trust_anchor_cert.cert_pem,
    issuerTlsCrtPEM = tls_locally_signed_cert.issuer_cert.cert_pem,
    issuerTlsKeyPEM = tls_private_key.issuer_key.private_key_pem
  }
  description = "The generated and required config field for linkerd identity module, this configs usually being generated/passed automatically when we use `linkerd` cli to install linkerd, but for terraform/helm install we need to generate them, for more info check README.md"
  sensitive   = true
}
