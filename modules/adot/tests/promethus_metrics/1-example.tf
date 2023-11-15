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

  cluster_name                = "stage-6"
  eks_oidc_root_ca_thumbprint = replace(try(data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn, ""), "/.*id//", "")
  oidc_provider_arn           = data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn
  region                      = "eu-central-1"

  adot_config = {
    log_group_name         = "adot_log_group"
    accept_namespace_regex = "(default|kube-system)"

    additional_metrics = [
      "pod_cpu_utilization",
      "kube_deployment_status_replicas_unavailable",
      "kube_deployment_status_replicas_available"
    ]
  }

  prometheus_metrics = [
    "kube_deployment_status_replicas_unavailable",
    "kube_deployment_status_replicas_available"
  ]

  depends_on = [
    helm_release.cert-manager
  ]
}
