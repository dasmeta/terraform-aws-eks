awsRegion: ${region}
clusterName: ${cluster_name}

fluentbit:
  enabled: false
adotCollector:
  image:
    name: "adot"
    repository: "amazon/aws-otel-collector"
    tag: "v0.27.0"
    daemonSetPullPolicy: "Always"
    sidecarPullPolicy: "Always"
  daemonSet:
    createNamespace: false
    namespace: adot
    serviceAccount:
      create: false
      annotations: {}
      name: "adot-collector"
    service:
      create: true
    adotConfig:
      extensions:
        health_check: {}
      receivers:
        awscontainerinsightreceiver:
          collection_interval: 61s
          container_orchestrator: eks
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
        prometheus:
          config:
            global:
              scrape_interval: 60s
              scrape_timeout: 10s
            scrape_configs:
              - job_name: kubernetes-service-endpoints
                sample_limit: 10000
                kubernetes_sd_configs:
                - role: endpoints
                relabel_configs:
                - action: keep
                  regex: true
                  source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_scrape
                - action: replace
                  regex: (https?)
                  source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_scheme
                  target_label: __scheme__
                - action: replace
                  regex: (.+)
                  source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_path
                  target_label: __metrics_path__
                - action: replace
                  regex: ([^:]+)(?::\d+)?;(\d+)
                  replacement: $$1:$$2
                  source_labels:
                  - __address__
                  - __meta_kubernetes_service_annotation_prometheus_io_port
                  target_label: __address__
                - action: labelmap
                  regex: __meta_service_pod_label_(.+)
                metric_relabel_configs:
                - action: keep
                  source_labels:
                  - namespace
                  regex: ${accept_namespace_regex}
                - action: replace
                  source_labels:
                  - namespace
                  target_label: Namespace
                - action: replace
                  source_labels:
                  - deployment
                  target_label: Deployment
      processors:
        batch/metrics:
          timeout: 60s
        filter/namespaces:
          metrics:
            include:
              match_type: regexp
              resource_attributes:
              - key: Namespace
                value: ${accept_namespace_regex}
        filter/metrics_include:
          metrics:
            include:
              match_type: regexp
              metric_names:
%{ for value in metrics }
              - ^${value}$
%{ endfor ~}
        resource/set_attributes:
          attributes:
            - key: ClusterName
              value: "${cluster_name}"
              action: insert
        resource/tracing_attributes:
          attributes:
            - key: appdynamics.controller.host
              value: "${cluster_name}"
              action: upsert
        batch/tracing:
          timeout: 30s
          send_batch_size: 8192
        memory_limiter:
          limit_mib: 100
          check_interval: 5s
      exporters:
        awsemf/prometheus:
          dimension_rollup_option: NoDimensionRollup
          log_group_name: "${log_group_name}"
          log_stream_name: "adot-metrics-prometheus"
          metric_declarations:
          - dimensions:
            - - Namespace
              - Deployment
            metric_name_selectors:
            - kube_deployment_status_replicas_available
            - kube_deployment_spec_replicas
            - kube_deployment_status_replicas_ready
%{ for key,value in prometheus_metrics }
          - dimensions: ${key}
            metric_name_selectors: ${jsonencode(value)}
%{ endfor ~}
          namespace: ContainerInsights
          parse_json_encoded_attr_values:
          - Sources
          - kubernetes
          region: "${region}"
          resource_to_telemetry_conversion:
            enabled: true
        awsemf:
          namespace: "ContainerInsights"
          log_group_name: "${log_group_name}"
          log_stream_name: "adot-metrics"
          region: "${region}"
          dimension_rollup_option: "NoDimensionRollup"
          resource_to_telemetry_conversion:
            enabled: true
          parse_json_encoded_attr_values: [Sources, kubernetes]
          metric_declarations:
          # node metrics
          - dimensions: [[PodName, Namespace, ClusterName]]
            metric_name_selectors:
              - pod_number_of_container_restarts
              - pod_cpu_utilization
              - pod_memory_utilization
              - pod_network_tx_bytes
              - pod_network_rx_bytes
          - dimensions: [[ClusterName]]
            metric_name_selectors:
              - node_cpu_utilization
              - node_memory_utilization
              - node_network_total_bytes
              - node_cpu_reserved_capacity
              - node_number_of_running_pods
              - node_number_of_running_containers
              - node_cpu_usage_total
              - node_cpu_limit
              - node_memory_working_set
              - node_memory_limit
              - node_network_tx_bytes
              - node_network_rx_bytes
              - node_disk_utilization
              - kube_deployment_spec_replicas
              - kube_deployment_status_replicas_available
          # pod metrics
          - dimensions: [[PodName, Namespace, ClusterName], [Service, Namespace, ClusterName], [Namespace, ClusterName], [ClusterName]]
            metric_name_selectors:
              - pod_cpu_utilization
              - pod_memory_utilization
              - pod_network_rx_bytes
              - pod_network_tx_bytes
              - pod_cpu_utilization_over_pod_limit
              - pod_memory_utilization_over_pod_limit
          - dimensions: [[PodName, Namespace, ClusterName], [ClusterName]]
            metric_name_selectors:
              - pod_cpu_reserved_capacity
              - pod_memory_reserved_capacity
          - dimensions: [[PodName, Namespace, ClusterName]]
            metric_name_selectors:
              - pod_number_of_container_restarts
              - container_cpu_limit
              - container_cpu_request
              - container_cpu_utilization
              - container_memory_limit
              - container_memory_request
              - container_memory_utilization
              - container_memory_working_set

          # cluster metrics
          - dimensions: [[ClusterName]]
            metric_name_selectors:
              - cluster_node_count
              - cluster_failed_node_count

          # service metrics
          - dimensions: [[Service, Namespace, ClusterName], [ClusterName]]
            metric_name_selectors:
              - service_number_of_running_pods

          # node fs metrics
          - dimensions: [[NodeName, InstanceId, ClusterName], [ClusterName]]
            metric_name_selectors:
              - node_filesystem_utilization

          # namespace metrics
          - dimensions: [[Namespace, ClusterName], [ClusterName]]
            metric_name_selectors:
              - namespace_number_of_running_pods
        logging:
          loglevel: debug
        awsxray:
          region: "${region}"
      service:
        pipelines:
          metrics/awsemf_prometheus:
            exporters: ["awsemf/prometheus"]
            processors: ["resource/set_attributes"]
            receivers: ["prometheus"]
          metrics/awsemf_namespace_specific:
            receivers: ["awscontainerinsightreceiver"]
            processors: ["filter/metrics_include", "filter/namespaces", "resource/set_attributes", "batch/metrics"]
            exporters: ["awsemf"]
          metrics/awsemf:
            receivers: ["awscontainerinsightreceiver", "prometheus"]
            processors: ["filter/metrics_include", "resource/set_attributes", "batch/metrics"]
            exporters: ["awsemf"]
          traces/logging:
            receivers: ["otlp"]
            processors: ["memory_limiter"]
            exporters: ["logging"]
          traces/to-aws-xray:
            receivers: [otlp]
            processors: ["memory_limiter", "batch/tracing", "resource/tracing_attributes"]
            exporters: ["awsxray"]
        extensions: ["health_check"]
