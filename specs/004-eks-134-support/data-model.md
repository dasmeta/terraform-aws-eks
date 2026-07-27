# Data Model: EKS 1.34 Module Support

## Version Defaults

Represents module-owned default versions that change with this feature.

| Field | Location | New Default | Notes |
|-------|----------|-------------|-------|
| `cluster_version` | root, `modules/eks`, `modules/adot`, `modules/ebs-csi`, `modules/s3-csi` | `1.34` | Drives EKS and managed add-on compatibility |
| `eks_version` | `modules/autoscaler` | `1.34` | Used in Cluster Autoscaler image tag |
| `autoscaler_image_patch` | root, `modules/autoscaler` | `3` | Builds default image `v1.34.3` |
| `keda.keda_version` | root, `modules/keda` | `2.20.0` | KEDA chart version |
| `external_secrets_chart_version` | root, `modules/external-secrets` | `2.8.0` | ESO chart version |
| `metrics_server_chart_version` | root, `modules/metrics-server` | `7.4.12` | Bitnami metrics-server chart |
| `kube_state_metrics_chart_version` | root | `7.8.1` | prometheus-community chart |
| `nginx_ingress_controller_config.chart_version` | root, `modules/nginx-ingress-controller` | `4.15.1` | ingress-nginx chart |
| `linkerd.chart_repository` | root, `modules/linkerd` | `https://helm.linkerd.io/edge` | Linkerd edge chart repository |
| `linkerd.crds_chart_version` | root, `modules/linkerd` | `2025.10.7` | Linkerd CRDs chart |
| `linkerd.chart_version` | root, `modules/linkerd` | `2025.10.7` | Linkerd control plane chart |
| `linkerd.viz_chart_version` | root, `modules/linkerd` | `2025.10.7` | Linkerd viz chart |

## Compatibility Notes

Represents migration guidance rendered through terraform-docs from `main.tf`.

Required content:

- EKS 1.34 default and EKS 1.33 extended support date.
- No live client cluster delivery in this ticket.
- Staged no-downtime delivery: tooling first with `cluster_version` pinned, then EKS control-plane upgrade.
- AL2023 node image requirement for EKS 1.34.
- Cluster Autoscaler `v1.34.3`.
- Linkerd production rollout requirements and old-version pin escape hatch.
- External Secrets `v1beta1` to `v1` migration.
- ingress-nginx retirement and Gateway API recommendation.
- Compatible components intentionally left unchanged.
- Deprecated/removed API scan result.

## Example API Versions

Examples using External Secrets API must use:

```text
external-secrets.io/v1
```

Historical upgrade notes may mention `external-secrets.io/v1beta1` only as legacy state/import context.
