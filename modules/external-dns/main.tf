resource "helm_release" "this" {
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = true
  wait             = false

  values = [
    jsonencode(merge(
      {
        aws = { region = local.region }
        serviceAccount = {
          create      = true
          name        = var.service_account_name
          annotations = { "eks.amazonaws.com/role-arn" = module.role.arn }
        }
      },
      var.configs
    ))
  ]

  depends_on = [
    module.role
  ]
}
