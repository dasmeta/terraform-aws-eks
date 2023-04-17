module "this" {
  source = "../../"

  name = "audit-project"

  enable_cloudwatch_logs      = true
  cloud_watch_logs_group_name = "audit-project-cloudtrail-logs"

  alerts = {
    events = ["iam-user-creation-or-deletion"]
  }
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

  cluster_name                = "cluster_name"
  eks_oidc_root_ca_thumbprint = replace("eks_oidc_provider_arn", "/.*id//", "")
  oidc_provider_arn           = "eks_oidc_provider_arn"
  region                      = "region"
  adot_config = {
    accept_namespace_regex = "(default|kube-system)"

  }
  depends_on = [
    helm_release.cert-manager
  ]
}
