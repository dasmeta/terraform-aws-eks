awsRegion: ${region}
clusterName: ${cluster_name}

serviceAccount:
  create: false
  annotations: {}
  name: "adot-collector"
fluentbit:
  enabled: false
adotCollector:
  image:
    name: "adot"
    repository: "dasmeta/adot"
    tag: "latest"
    daemonSetPullPolicy: "Always"
    sidecarPullPolicy: "Always"
  daemonSet:
    createNamespace: false
    namespace: adot
    cwexporters:
      namespace: "ContainerInsights"
      logGroupName: "${log_group_name}"
      logStreamName: "adot-metrics"
      enabled: true
      dimensionRollupOption: "NoDimensionRollup"
      parseJsonEncodedAttrValues: ["Sources", "kubernetes"]
    ampreceivers:
      scrapeInterval: 60s
      scrapeTimeout: 10s
      scrapeConfigs: |
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
            replacement: $1:$2
            source_labels:
            - __address__
            - __meta_kubernetes_service_annotation_prometheus_io_port
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - action: replace
            source_labels:
            - __meta_kubernetes_service_name
            target_label: Service
          - action: replace
            source_labels:
            - __meta_kubernetes_pod_node_name
            target_label: kubernetes_node
          - action: replace
            source_labels:
            - __meta_kubernetes_pod_name
            target_label: pod_name
          - action: replace
            source_labels:
            - __meta_kubernetes_pod_container_name
            target_label: container_name
          metric_relabel_configs:
          - action: drop
            regex: ${drop_namespace_regex}
            source_labels:
            - namespace
          - action: replace
            source_labels:
            - namespace
            target_label: Namespace
          - action: replace
            source_labels:
            - deployment
            target_label: Deployment
          - source_labels: [__name__]
            regex: 'go_gc_duration_seconds.*'
            action: drop

    processors:
      timeout: 60s
      additionalProcessors: |
        resource/set_attributes:
          attributes:
            - key: ClusterName
              value: ${cluster_name}
              action: insert
        filter/namespaces:
          metrics:
            exclude:
              match_type: regexp
              resource_attributes:
              - Key: Namespace
                Value: ${drop_namespace_regex}
    metricDeclarations: |
      - dimensions: [[PodName, Namespace, ClusterName]]
        metric_name_selectors:
          - pod_number_of_container_restarts
          - pod_cpu_utilization
          - pod_memory_utilization
          - pod_network_tx_bytes
          - pod_network_rx_bytes
      - dimensions: [[ClusterName]]
        metric_name_selectors:
          - cluster_failed_node_count
          - cluster_node_count
      - dimensions: [[InstanceId, ClusterName]]
        metric_name_selectors:
          - node_number_of_running_pods
          - node_cpu_utilization
          - node_memory_utilization
          - node_network_tx_bytes
          - node_network_rx_bytes
          - node_disk_utilization
      - dimensions: [[Deployment, Namespace, ClusterName]]
        metric_name_selectors:
          - kube_deployment_spec_replicas
          - kube_deployment_status_replicas_available
    service:
      metrics:
        receivers: ["awscontainerinsightreceiver", "prometheus"]
        processors: ["filter/namespaces", "resource/set_attributes", "batch/metrics"]
        exporters: ["awsemf"]
      extensions: ["health_check"]
