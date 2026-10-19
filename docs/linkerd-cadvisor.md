# Disable duplicate Linkerd Viz container collection

Linkerd Viz 2025.10.7 hardcodes a cluster-wide cAdvisor scrape. Its
`prometheus.scrapeConfigs` only appends jobs, and `metricRelabelConfigs` affects
the proxy scrape. Neither disables that built-in job.

When another collector already provides CPU, memory, network and filesystem
metrics, use the root module input:

```hcl
linkerd = {
  prometheus_cadvisor_enabled = false
}
```

For a YAML DSL consumer, after upgrading to a released module containing this
option, merge this into the existing environment EKS variables:

```yaml
variables:
  linkerd:
    prometheus_cadvisor_enabled: false
```

Do not use this setting with an older version: Terraform object conversion can
silently discard unrecognized attributes. Keep existing Linkerd settings and
the environment's other values. Upgrade the module pin and regenerate through
the normal DSL workflow; do not edit generated Terraform directly. The first
intended rollout is development only. No release number is invented here.

The default is `true` for backward compatibility. On opt-out, Helm applies a
post-renderer to remove only `kubernetes-nodes-cadvisor` from its own ConfigMap.
Helm retains sole ownership; later reconciliations retain the opt-out. The
Terraform/Helm runner needs `/bin/sh` and `awk` (Linux/macOS); it does not need
Python or cluster access for rendering. Helm CLI operations must use the same
postrenderer, for example `--post-renderer /bin/sh --post-renderer-args
/path/to/modules/linkerd/scripts/without-cadvisor.sh --post-renderer-args
linkerd-viz`. Unsupported chart layouts fail visibly and require review.

The chart mounts its config with `subPath`. For an existing installation,
restart only the Viz Prometheus Deployment once after a configuration-changing
apply, then verify its loaded configuration and active targets. The module does
not add a new automatic restart policy. Viz's ephemeral local history is reset
on pod replacement; the separate main collector is unaffected.

Before rollout, confirm separate fresh container metrics, review the plan,
and check dashboards querying Viz directly. After rollout, verify no cAdvisor
targets, retained Linkerd targets, and fresh main-collector data. The equivalent
live dev patch was tested separately; production has not been changed.

## Local verification

From `modules/linkerd`, initialize with `terraform init -backend=false`, then
run `terraform validate` and `terraform test` (Terraform >=1.7 for mocked tests,
Helm provider 2.x matching the root wrapper). Render tests require Helm 3,
Python 3 and PyYAML, plus an already downloaded official chart archive:

```sh
LINKERD_VIZ_CHART=/path/to/linkerd-viz-2025.10.7.tgz python3 -m unittest discover -s tests -p 'test_*.py'
```

The chart test compares every rendered resource and every remaining scrape job,
and verifies unsupported layouts cannot emit partial output. No test contacts
or mutates a Kubernetes cluster.
