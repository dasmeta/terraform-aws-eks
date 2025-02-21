locals {
  default_metrics = [
    "cluster_node_count",
    "cluster_failed_node_count",
    "node_filesystem_utilization",
    "node_cpu_usage_total",
    "node_cpu_limit",
    "node_cpu_utilization",
    "node_memory_working_set",
    "node_memory_limit",
    "node_memory_utilization",
    "node_network_tx_bytes",
    "node_network_rx_bytes",
  ]

  default_metrics_namespace_specific = [
    "namespace_number_of_running_pods",
    "service_number_of_running_pods",
    "pod_number_of_container_restarts",
    "pod_cpu_usage_total",
    "pod_cpu_limit",
    "pod_memory_working_set",
    "pod_memory_limit",
    "pod_network_tx_bytes",
    "pod_network_rx_bytes",
  ]

  merged_metrics            = concat(local.default_metrics, lookup(var.adot_config, "additional_metrics", []))
  merged_namespace_specific = concat(local.default_metrics_namespace_specific, lookup(var.adot_config, "namespace_specific_metrics", []))

  adot_policies = concat([
    "${aws_iam_policy.adot.arn}",
    "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  ], var.adot_collector_policy_arns)

  addon_name           = "adot"
  service_account_name = "adot-collector"
  oidc_provider        = regex("^arn:aws:iam::[0-9]+:oidc-provider/(.*)$", var.oidc_provider_arn)[0]
  region               = coalesce(var.region, try(data.aws_region.current[0].name, null))


  logging = var.adot_config.logging_enable ? {
    "log_group_name"  = "${var.adot_config.log_group_name}"
    "log_stream_name" = "adot-metrics"
    "log_retention"   = "${var.adot_config.log_retention}"
  } : {}
}
