locals {
  adot_log_group_name  = "adot-log-group-dasmeta"
  service_account_name = "adot-collector"
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
  version          = "0.14.1"
  create_namespace = false
  atomic           = true
  wait             = false

  values = [
    templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region                 = local.region
      cluster_name           = var.cluster_name
      accept_namespace_regex = var.adot_config.accept_namespace_regex
      log_group_name         = local.adot_log_group_name
      metrics                = local.merged_metrics
    })
  ]

  depends_on = [
    aws_eks_addon.this,
    aws_iam_role.adot_collector
  ]
}
