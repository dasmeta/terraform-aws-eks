resource "helm_release" "fluent-bit" {
  name       = local.fluent_name
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.20.9"
  namespace  = var.namespace

  values = [
    templatefile("${path.module}/values.yaml", { log_group_name = local.log_group_name, region = local.region })
  ]

  set {
    name  = "clusterName"
    value = var.cluster_name
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
