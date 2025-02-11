
module "cw_alerts" {
  count = var.alarms.enabled ? 1 : 0

  source  = "dasmeta/monitoring/aws//modules/alerts"
  version = "1.3.5"

  sns_topic = var.alarms.sns_topic

  alerts = [
    {
      name   = "EKS ${var.cluster_name} node failed"
      source = "ContainerInsights/ClusterName/cluster_failed_node_count"
      filters = {
        ClusterName = var.cluster_name
      }
      period    = try(var.alarms.custom_values.node_failed.period, "60")
      threshold = try(var.alarms.custom_values.node_failed.threshold, "1")
      statistic = try(var.alarms.custom_values.node_failed.statistic, "max")
    },
  ]

  depends_on = [module.eks-cluster]
}
