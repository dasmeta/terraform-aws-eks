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
  eks_oidc_root_ca_thumbprint = replace(try(data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn, ""), "/.*id//", "")
  oidc_provider_arn           = data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn
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
