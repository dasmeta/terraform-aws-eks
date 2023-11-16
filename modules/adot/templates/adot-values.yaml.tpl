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
    namespace: ${namespace}
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
          collection_interval: 10s
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
                # collect if service.annotation: prometheus.io/scrape: true
                - source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_scrape
                  regex: true
                  action: keep
                # replaces the schema
                - source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_scheme
                  regex: (https?)
                  action: replace
                  target_label: __scheme__
                - source_labels:
                  - __meta_kubernetes_service_annotation_prometheus_io_path
                  regex: (.+)
                  action: replace
                  target_label: __metrics_path__
                - source_labels:
                  - __address__
                  - __meta_kubernetes_service_annotation_prometheus_io_port
                  regex: ([^:]+)(?::\d+)?;(\d+)
                  action: replace
                  replacement: $$1:$$2
                  target_label: __address__
                - regex: __meta_service_pod_label_(.+)
                  action: labelmap
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
        filter/metrics_namespace_specific:
          metrics:
            include:
              match_type: regexp
              metric_names:
%{ for value in metrics_namespace_specific }
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
              - ClusterName
              - Deployment
            metric_name_selectors:
            - kube_deployment_spec_replicas
            - kube_deployment_status_replicas_available
%{ for value in prometheus_metrics }
            - ${value}
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
          # cluster metrics
          - dimensions: [[ClusterName]]
            metric_name_selectors:
              - cluster_node_count
              - cluster_failed_node_count

              # (OK) node fs metrics - used to catch disk pressures (should be used with max)
              - node_filesystem_utilization

              - node_cpu_usage_total
              - node_cpu_limit
              - node_cpu_utilization

              - node_memory_working_set
              - node_memory_limit
              - node_memory_utilization

              - node_network_tx_bytes
              - node_network_rx_bytes

              # - node_disk_utilization
              # - node_number_of_running_containers
              # - node_number_of_running_pods

          - dimensions: [[ClusterName, Namespace]]
            metric_name_selectors:
              # (OK) namespace metrics - used to performance tune giant workloads (prefect)
              - namespace_number_of_running_pods

          - dimensions: [[ClusterName, Namespace, Service]]
            metric_name_selectors:
              # (OK) service metrics - used to performance tune deployments
              - service_number_of_running_pods

          #- dimensions: [[ClusterName, Namespace, Deployment]]
            #metric_name_selectors:
              # Check for HPA maximum
              #- kube_deployment_spec_replicas # CHECK
              #- kube_deployment_status_replicas_available # CHECK

          - dimensions: [[ClusterName, Namespace, PodName]]
            metric_name_selectors:
              - pod_number_of_container_restarts
              - pod_cpu_usage_total
              - pod_cpu_limit
              - pod_memory_working_set
              - pod_memory_limit
              - pod_network_tx_bytes
              - pod_network_rx_bytes

          #- dimensions: [[ClusterName, Namespace, PodName, Phase]]
          #  metric_name_selectors:
          #    - kube_pod_status_phase

          # - dimensions: [[ClusterName, Namespace, Volume]]
          #  metric_name_selectors:
        logging:
          loglevel: error
        awsxray:
          region: "${region}"
      service:
        pipelines:
          metrics/awsemf_prometheus:
            receivers: ["prometheus"]
            processors: ["resource/set_attributes"]
            exporters: ["awsemf/prometheus"]
          metrics/awsemf_namespace_specific:
            receivers: ["awscontainerinsightreceiver", "prometheus"]
            processors: ["filter/metrics_namespace_specific", "filter/namespaces", "resource/set_attributes", "batch/metrics"]
            exporters: ["awsemf"]
          metrics/awsemf:
            receivers: ["awscontainerinsightreceiver"]
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
