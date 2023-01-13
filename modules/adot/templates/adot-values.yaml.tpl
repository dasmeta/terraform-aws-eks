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
          - action: replace
            source_labels:
            - namespace
            target_label: Namespace
          - action: replace
            source_labels:
            - deployment
            target_label: Deployment
          - action: replace
            source_labels:
            - container
            target_label: Container
          - action: replace
            source_labels:
            - pod
            target_label: Pod
          - action: replace
            source_labels:
            - phase
            target_label: Phase
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
            include:
              match_type: regexp
              resource_attributes:
              - Key: Namespace
                Value: ${accepte_namespace_regex}
    metricDeclarations: |
%{ for key,value in metrics }
      - dimensions: ${key}
        metric_name_selectors: ${jsonencode(value)}
%{ endfor ~}
    service:
      metrics:
        receivers: ["awscontainerinsightreceiver", "prometheus"]
        processors: ["filter/namespaces", "resource/set_attributes", "batch/metrics"]
        exporters: ["awsemf"]
      extensions: ["health_check"]
