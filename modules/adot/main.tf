# TODO: check if we really need to install this chart, its looks like all the abilities of adot can be configured by just using eks adot addon, check docs: https://aws-otel.github.io/docs/getting-started/adot-eks-add-on and https://github.com/aws-observability/aws-otel-helm-charts?tab=readme-ov-file
resource "helm_release" "adot-collector" {
  name             = "adot-collector"
  repository       = "https://dasmeta.github.io/aws-otel-helm-charts"
  chart            = "adot-exporter-for-eks-on-ec2"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  wait             = false

  values = [
    contains(keys(var.adot_config), "helm_values")
    && try(var.adot_config.helm_values, "") != null ?
    var.adot_config.helm_values :
    templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region                     = local.region
      cluster_name               = var.cluster_name
      accept_namespace_regex     = var.adot_config.accept_namespace_regex
      loging                     = local.logging
      metrics                    = local.merged_metrics
      metrics_namespace_specific = local.merged_namespace_specific
      prometheus_metrics         = var.prometheus_metrics
      namespace                  = var.namespace
      resources_limit_cpu        = var.adot_config.resources.limit["cpu"]
      resources_limit_memory     = var.adot_config.resources.limit["memory"]
      resources_requests_cpu     = var.adot_config.resources.requests["cpu"]
      resources_requests_memory  = var.adot_config.resources.requests["memory"]
      limit_mib                  = var.adot_config.memory_limiter.limit_mib
      check_interval             = var.adot_config.memory_limiter.check_interval
    })
  ]

  depends_on = [
    aws_eks_addon.this,
    aws_iam_role.adot_collector
  ]
}
