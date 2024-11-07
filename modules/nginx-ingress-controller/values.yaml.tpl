controller:
  config:
    use-forwarded-headers: "true"
    enable-underscores-in-headers: 'true'
  replicaCount: ${replicacount}
%{ if metrics_enabled ~}
  podAnnotations:
    prometheus.io/scrape: true
    prometheus.io/port: 10254
%{ endif ~}

  metrics:
    enabled: ${metrics_enabled}
