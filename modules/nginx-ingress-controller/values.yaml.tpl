controller:
  config:
    use-forwarded-headers: "true"
    enable-underscores-in-headers: 'true'
  replicaCount: ${replicacount}

  metrics:
    enabled: ${metrics_enabled}
