locals {
  cluster_name = "eks"
}
resource "helm_release" "cert-manager" {
  namespace        = "cert-manager"
  create_namespace = true
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  atomic           = true
  set {
    name  = "installCRDs"
    value = "true"
  }
}

module "adot" {
  source = "../../"

  cluster_name                = local.cluster_name
  eks_oidc_root_ca_thumbprint = "eks_oidc_root_ca_thumbprint"
  oidc_provider_arn           = "arn:aws:iam::4567654567:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/7657897654678976"
  region                      = "eu-central-1"
  adot_config = {
    helm_values = templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region         = "eu-central-1"
      cluster_name   = local.cluster_name
      log_group_name = "/aws/containerinsights/${local.cluster_name}/adot"
    })
  }
  depends_on = [
    helm_release.cert-manager
  ]
}
