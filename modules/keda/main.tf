resource "helm_release" "keda" {
  name             = var.name
  namespace        = var.namespace
  create_namespace = var.create_namespace

  repository = "https://kedacore.github.io/charts"
  chart      = var.chart_name
  version    = var.keda_version

  values = [templatefile("${path.module}/values.yaml.tpl", {
    role_arn = aws_iam_role.keda-role.arn
    })
  ]
}
