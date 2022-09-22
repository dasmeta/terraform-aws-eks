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
    name: ingress-name
    host: weave.miandevops.xyz
    path: "/"
    className: ""
    extraPaths: ""
    annotations:
      %{~ for config_key, config_value in config ~}
      "${config_key}": "${config_value}"
        %{~ endfor ~}

  service:
    serviceName: weave-weave-scope
    servicePort: 80
    externalPort: 8080

  hosts:
    - name: chartmuseum.domain1.com
      path: /
      tls: false
    - name: chartmuseum.domain2.com
      path: /
weave-scope-agent:
  enabled: true
  dockerBridge: "docker0"
  scopeFrontendAddr: ""
  probeToken: ""
  rbac:
    create: true
  readOnly: false
  serviceAccount:
    create: true
