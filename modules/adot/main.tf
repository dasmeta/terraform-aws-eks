locals {
  service_account_name = "adot-collector"
  oidc_provider        = regex("^arn:aws:iam::[0-9]+:oidc-provider/(.*)$", var.oidc_provider_arn)[0]
  region               = coalesce(var.region, try(data.aws_region.current[0].name, null))
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

resource "helm_release" "adot-collector" {
  name             = "adot-collector"
  repository       = "https://dasmeta.github.io/aws-otel-helm-charts"
  chart            = "adot-exporter-for-eks-on-ec2"
  namespace        = "adot"
  version          = "0.15.5"
  create_namespace = false
  atomic           = true
  wait             = false

  values = [
    var.adot_config.helm_values == null ?
    templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region                 = local.region
      cluster_name           = var.cluster_name
      accept_namespace_regex = var.adot_config.accept_namespace_regex
      log_group_name         = var.adot_log_group_name
      metrics                = local.merged_metrics
      prometheus_metrics     = var.prometheus_metrics
    }) : var.adot_config.helm_values
  ]

  depends_on = [
    aws_eks_addon.this,
    aws_iam_role.adot_collector
  ]
}
