resource "helm_release" "this" {
  name             = var.release_name
  repository       = var.chart_repository
  chart            = var.chart_name
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait

  values = [
    jsonencode({
      # kubernetes-sigs external-dns chart: https://kubernetes-sigs.github.io/external-dns/
      provider = {
        name = "aws"
      }
      sources = ["service", "ingress", "gateway-httproute", "gateway-grpcroute"]
      serviceAccount = {
        create      = true
        name        = var.service_account_name
        annotations = { "eks.amazonaws.com/role-arn" = module.role.arn }
      }
      env = [
        { name = "AWS_REGION", value = local.region }
      ]
    }),
    jsonencode(var.configs)
  ]

  depends_on = [
    module.role
  ]
}
