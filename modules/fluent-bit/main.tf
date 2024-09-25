/**
 * # Example Setup
 *
 * ```tf
 * module "fluent-bit" {
 *   source  = "dasmeta/eks/aws//modules/fluent-bit"
 *   version = "0.1.4"
 *
 *   cluster_name                = "eks-cluster-name"
 *   oidc_provider_arn           = "eks_oidc_provider_arn"
 *   eks_oidc_root_ca_thumbprint = replace("eks_oidc_provider_arn", "/.*id//", "")
 * }
 * ```
 */

resource "helm_release" "fluent-bit" {
  name       = local.fluent_name
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.30.3"
  namespace  = var.namespace

  values = [
    local.values
  ]

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "imagePullSecrets"
    value = var.imagePullSecrets
  }

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::${var.account_id}:role/${aws_iam_role.fluent-bit.name}"
  }
}
