module "identity_certificates_and_keys" {
  source = "./modules/identity-certificates-and-keys"
}

module "webhook_certificates_and_keys" {
  source = "./modules/webhook-certificates-and-keys"

  namespace = var.namespace
}
