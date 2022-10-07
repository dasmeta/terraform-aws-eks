global:
  image:
    repository: weaveworks/scope
    tag: 1.10.1
    pullPolicy: "IfNotPresent"
  service:
    port: 80
    type: ${service_type}
weave-scope-frontend:
  enabled: true

  ingress:
    enabled: enabled
    name: ${ingress_name}
    host: ${ingress_host}
    path: "/"
    className: ${ingress_class}
    extraPaths: ""
    annotations:
      %{~ for config_key, config_value in config ~}
      "${config_key}": "${config_value}"
        %{~ endfor ~}

  service:
    serviceName: weave-weave-scope
    servicePort: 80
    externalPort: 8080

weave-scope-agent:
  enabled: true
  dockerBridge: "docker0"
  scopeFrontendAddr: ""
  probeToken: ""
  rbac:
    create: true
  readOnly: ${read_only}
  serviceAccount:
    create: true
