locals {
  default_metrics = [
    "cluster_failed_node_count",
    "cluster_node_count",
    "node_cpu_limit",
    "node_cpu_reserved_capacity",
    "node_cpu_utilization",
    "node_memory_limit",
    "node_memory_utilization",
    "node_filesystem_utilization",
    //TODO: these 2 metrics are not exported, check why and fix
    # "kube_deployment_spec_replicas",
    # "kube_deployment_status_replicas_available"
  ]
  default_metrics_namespace_specific = [
    "pod_number_of_container_restarts",
    "pod_cpu_utilization",
    "pod_memory_utilization",
    "pod_network_tx_bytes",
    "pod_network_rx_bytes",
    "service_number_of_running_pods",
    "pod_cpu_reserved_capacity",
    "pod_memory_reserved_capacity",
  ]

  merged_metrics            = concat(local.default_metrics, lookup(var.adot_config, "additional_metrics", []))
  merged_namespace_specific = concat(local.default_metrics_namespace_specific, lookup(var.adot_config, "namespace_specific_metrics", []))
}
