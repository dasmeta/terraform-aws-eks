/**
 * # external-secrets controller
 *
 * Installs the external-secrets controller via Helm and provisions the AWS identity it runs
 * as (EKS Pod Identity association by default, IRSA optional). Static IAM users / access keys
 * are never created. The chart source supports both a standard Helm repo and a direct
 * compressed .tgz endpoint, and controller/webhook/cert-controller images can be overridden
 * to a private registry.
 */

resource "helm_release" "this" {
  name             = var.release_name
  repository       = local.chart_is_url ? null : var.chart.repository
  chart            = var.chart.name
  version          = local.chart_is_url ? null : var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait
  timeout          = var.timeout

  # Later entries win in Helm: base config, then image overrides, then caller values/extras.
  values = [
    jsonencode(local.base_values),
    jsonencode(local.image_values),
    jsonencode(var.values),
    jsonencode(var.extra_values),
  ]
}
