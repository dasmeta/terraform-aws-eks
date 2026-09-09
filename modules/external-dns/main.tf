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
      sources = local.external_dns_sources
      serviceAccount = {
        create      = true
        name        = var.service_account_name
        annotations = { "eks.amazonaws.com/role-arn" = module.role.arn }
      }
      env = [
        { name = "AWS_REGION", value = local.region }
      ]
      # The upstream chart sets no resource requests at all. Karpenter sizes nodes from REQUESTS, so a pod
      # without them contributes nothing to that calculation: capacity gets provisioned as if this pod were
      # free, and after every disruption it is among the first to sit Pending. Small values are enough --
      # the point is that the pod is counted, not that the numbers are generous.
      #
      # No memory limit on purpose. Usage here scales with the number of records in the zones being watched,
      # so a limit that suits a small zone becomes an OOMKill on a large one. Override through `configs` if a
      # cluster needs one.
      resources = {
        requests = {
          cpu    = "25m"
          memory = "64Mi"
        }
      }
    }),
    jsonencode(var.configs)
  ]

  depends_on = [
    module.role
  ]
}
