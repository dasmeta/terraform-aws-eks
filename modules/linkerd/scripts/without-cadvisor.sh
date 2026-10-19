#!/bin/sh
# Helm postrenderer for the pinned Linkerd Viz chart. No Kubernetes access.
set -eu
if [ "$#" -ne 1 ]; then
  echo "usage: without-cadvisor.sh VIZ_NAMESPACE" >&2
  exit 2
fi
awk -v namespace="$1" '
  /^---[[:space:]]*$/ {
    configmap = 0; target = 0; expected_namespace = 0; skipping = 0
  }
  /^kind: ConfigMap[[:space:]]*$/ { configmap = 1 }
  /^  name: prometheus-config[[:space:]]*$/ { target = 1 }
  $0 == "  namespace: " namespace { expected_namespace = 1 }
  configmap && target && expected_namespace &&
    /^    - job_name: [\047"]?kubernetes-nodes-cadvisor[\047"]?[[:space:]]*$/ {
      removed++; skipping = 1; next
    }
  skipping && /^    - job_name:/ { skipping = 0 }
  !skipping { output[++lines] = $0 }
  END {
    if (removed != 1) {
      print "Expected exactly one Linkerd Viz cAdvisor job; refusing an unsupported chart layout." > "/dev/stderr"
      exit 1
    }
    for (i = 1; i <= lines; i++) print output[i]
  }
'
