locals {
  adot_log_group_name  = "adot-log-group-dasmeta"
  service_account_name = "adot-collector"
}

data "aws_region" "current" {}


resource "helm_release" "adot-collector" {
  name = "adot-collector"
  # the repo can be replaced when the required features are merged into https://github.com/aws-observability/aws-otel-helm-charts
  repository       = "https://makandra.github.io/aws-otel-helm-charts/"
  chart            = "adot-exporter-for-eks-on-ec2"
  namespace        = "adot"
  version          = "0.10.0"
  create_namespace = false
  atomic           = true
  wait             = false

  values = [
    templatefile("${path.module}/templates/adot-values.yaml.tpl", {
      region               = data.aws_region.current.name
      cluster_name         = var.cluster_name
      drop_namespace_regex = var.drop_namespace_regex
      log_group_name       = local.adot_log_group_name
    })
  ]

  depends_on = [
    aws_eks_addon.this,
    aws_iam_role.adot_collector
  ]
}

resource "aws_cloudwatch_log_group" "adot" {
  name              = local.adot_log_group_name
  retention_in_days = 3
  #   kms_key_id        = var.cloudwatch_log_group_kms_key_id
}
