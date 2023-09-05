module "external-secrets" {
  source = "./modules/external-secrets"

  count = var.create ? 1 : 0

  namespace = var.external_secrets_namespace

  depends_on = [
    module.eks-cluster
  ]
}
