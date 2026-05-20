/**
 * # Creates aws load balancer controller on eks cluster
 *
 * Docs and supported ingress annotations:
 * https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/
 *
 */

resource "helm_release" "aws-load-balancer-controller" {
  name             = "aws-load-balancer-controller"
  repository       = local.chart_repository
  chart            = var.chart.name
  version          = var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [
    jsonencode(local.default_values),
    jsonencode(var.configs)
  ]

  lifecycle {
    precondition {
      condition     = !(var.use_service_account_role_annotation && var.create_pod_identity_association)
      error_message = "use_service_account_role_annotation and create_pod_identity_association cannot both be true at the same time."
    }
  }
}
