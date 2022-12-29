locals {
  default_metrics = {
    "[[PodName, Namespace, ClusterName]]" = [
      "pod_number_of_container_restarts",
      "pod_cpu_utilization",
      "pod_memory_utilization",
      "pod_network_tx_bytes",
      "pod_network_rx_bytes"
    ]

    "[[ClusterName]]" = [
      "cluster_failed_node_count",
      "cluster_node_count",
      "namespace_number_of_running_pods",
      "service_number_of_running_pods",
      "node_number_of_running_containers",
      "node_number_of_running_pods",
      "node_network_total_bytes",
      "node_cpu_limit",
      "node_cpu_reserved_capacity",
      "node_cpu_utilization",
      "node_cpu_usage_total",
      "node_memory_limit",
      "node_memory_utilization",
      "node_memory_working_set",
      "node_filesystem_utilization",
      "pod_cpu_reserved_capacity",
      "pod_cpu_utilization",
      "pod_memory_utilization",
      "pod_memory_reserved_capacity",
      "pod_network_rx_bytes",
      "pod_network_tx_bytes"
    ]
    "[[InstanceId, ClusterName]]" = [
      "node_number_of_running_pods",
      "node_cpu_utilization",
      "node_memory_utilization",
      "node_network_tx_bytes",
      "node_network_rx_bytes",
      "node_disk_utilization"
    ]
    "[[Deployment, Namespace, ClusterName]]" = [
      "kube_deployment_spec_replicas",
      "kube_deployment_status_replicas_available"
    ]
  }

  merged_metrics = { for key, value in local.default_metrics : key => concat(value, lookup(lookup(var.adot_config, "additional_metrics", {}), key, [])) }
}
