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

    additional_metrics = [
      "pod_cpu_usage_total",
      "pod_cpu_limit",
      "pod_memory_working_set",
      "pod_memory_limit",
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
