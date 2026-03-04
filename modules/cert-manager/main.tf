# Install cert-manager Helm chart
resource "helm_release" "cert-manager" {
  namespace        = var.namespace
  create_namespace = var.create_namespace
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  atomic           = var.atomic
  version          = var.chart_version

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.dns01_role.iam_role_arn
        }
      }
    }),
    yamlencode(var.configs),
    yamlencode(var.extra_configs)
  ]

  depends_on = [module.dns01_role]
}
