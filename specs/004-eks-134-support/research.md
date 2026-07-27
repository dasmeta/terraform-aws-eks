# Research: EKS 1.34 Module Support

## Decisions

### Upgrade policy for live client delivery

- Decision: Upgrade only components that are required for Kubernetes 1.34 support; leave already-compatible components unchanged and track broader refreshes separately.
- Rationale: Client delivery should favor continuous/no-downtime operation and minimal per-setup manual changes. Tooling upgrades with manual migration requirements must not be bundled with the EKS control-plane upgrade when they can be staged separately.
- Consequences: Existing client rollout should be split into at least two applies: first adopt required tooling changes while pinning `cluster_version` to the current live version, then upgrade the EKS control plane after tooling health is verified. Components that already support Kubernetes 1.34 are documented as intentionally unchanged.

### EKS 1.34 as the module default

- Decision: Set root and affected submodule EKS/Kubernetes defaults to `1.34`.
- Rationale: AWS EKS 1.33 standard support ends on 2026-07-29 and then enters extended support billing. EKS 1.34 is in standard support until 2026-12-02.
- Consequences: Existing consumers can still set `cluster_version = "1.33"` or another supported version explicitly. Managed add-on data sources continue selecting compatible AWS add-on versions from `cluster_version`.

### Terraform EKS module major version

- Decision: Keep `terraform-aws-modules/eks/aws` on v20.x for this change.
- Rationale: v21.x raises Terraform/AWS provider requirements and removes/changes surfaces used by this module. Supporting EKS 1.34 does not require that major upgrade.
- Consequences: Avoids coupling the EKS version bump to a larger module migration.

### Components intentionally unchanged

- Decision: Do not change AWS Load Balancer Controller, Karpenter, cert-manager, Node Problem Detector, or AWS managed add-on selection behavior in this ticket.
- Rationale: Current defaults are already compatible with Kubernetes 1.34 or are resolved dynamically from `cluster_version`.
- Consequences: Broader refreshes for these tools can be handled in separate tickets when needed, without increasing the complexity of client EKS 1.34 delivery.

### Node AMI family

- Decision: Keep AL2023 as the managed node group default.
- Rationale: EKS 1.34 has no AL2 optimized AMI. Existing defaults already use `AL2023_x86_64_STANDARD`.
- Consequences: Consumers overriding old AL2 AMI types must move to AL2023 or another EKS 1.34 supported node image before cluster upgrades.

### Cluster Autoscaler

- Decision: Keep the image formula and change default patch from `0` to `3`, making the default image `registry.k8s.io/autoscaling/cluster-autoscaler:v1.34.3`.
- Rationale: Cluster Autoscaler publishes per-Kubernetes-minor images and `v1.34.3` is available.
- Consequences: Explicit overrides remain available through `autoscaler_image_patch`.

### Linkerd

- Decision: Move defaults from old stable 2.14-era charts to Linkerd 2.19 edge artifacts (`2025.10.7`) and expose `chart_repository`, `crds_chart_version`, `chart_version`, and `viz_chart_version` through the root `linkerd` object.
- Rationale: Linkerd 2.14 only supports Kubernetes up to 1.28. Linkerd 2.19 supports Kubernetes 1.34 and keeps a wider lower Kubernetes compatibility range than 2.20. Stable open-source artifacts are no longer the current distribution channel.
- Consequences: Existing production deployments require a staged Linkerd rollout: check current health, upgrade CRDs/control plane/extensions, restart meshed workloads, and validate with `linkerd check` and `linkerd check --proxy`. Consumers can pin old stable chart settings when adopting this module release before the Linkerd rollout, but that pin is not acceptable on an EKS 1.34 control plane.

### External Secrets Operator

- Decision: Upgrade default chart from `0.15.0` to `2.8.0` and expose `external_secrets_chart_version` at the root.
- Rationale: Current ESO support policy only supports recent minors; the old default is outside current support. API manifests using `external-secrets.io/v1beta1` must move to `external-secrets.io/v1` before upgrading past the 0.16 line.
- Consequences: Examples are updated to `external-secrets.io/v1`. Existing clusters must migrate ExternalSecret, SecretStore, and ClusterSecretStore resources before applying the chart upgrade.

### KEDA

- Decision: Upgrade KEDA default chart from `2.16.1` to `2.20.0`.
- Rationale: KEDA 2.20 is tested against Kubernetes 1.33-1.35; 2.16 is not in that range.
- Consequences: KEDA CRDs/resources should be checked in non-production before production rollout.

### Metrics Server

- Decision: Keep the existing Bitnami OCI chart family and bump from `7.4.1` to `7.4.12`, which moves the app from `0.7.2` to `0.8.0`.
- Rationale: Metrics Server 0.8.x supports Kubernetes 1.31+, including 1.34, and staying on the same chart family avoids the larger operational change of switching repositories/templates.
- Consequences: The existing Bitnami legacy image override remains in place.

### ingress-nginx

- Decision: Upgrade default chart from `4.12.0` to `4.15.1` and expose `chart_version` in `nginx_ingress_controller_config`.
- Rationale: Chart 4.12.0 does not support Kubernetes 1.34; 4.15.1 covers Kubernetes 1.31-1.35. The project is archived/retired, so new installs should prefer Gateway API where possible.
- Consequences: Existing ingress-nginx users must stage the controller upgrade and CRD/controller validation separately.

### kube-state-metrics

- Decision: Upgrade default chart from `5.27.0` to `7.8.1`.
- Rationale: The current chart app version is `2.19.1`, newer than the old `2.14.0` default and suitable for recent Kubernetes releases.
- Consequences: Enabled users should validate metric names consumed by alerts/dashboards after upgrade.

### Deprecated or removed APIs

- Decision: No module-owned core Kubernetes APIs removed in Kubernetes 1.34 were found in static scan.
- Rationale: Static scan found active core APIs (`apps/v1`, `rbac.authorization.k8s.io/v1`, `cert-manager.io/v1`) plus CRD-owned APIs (`keda.sh/v1alpha1`, ACK API Gateway v1alpha1). External Secrets examples used `external-secrets.io/v1beta1` and are updated to `external-secrets.io/v1`.
- Consequences: CRD-owned APIs still depend on their operators and must be validated as part of chart/operator upgrades.

## Sources Consulted

- AWS EKS Kubernetes versions and support policy
- AWS EKS 1.34 release notes
- Kubernetes deprecated API migration guide
- Linkerd Kubernetes version support and upgrade guides
- Cluster Autoscaler 1.34 release
- KEDA Kubernetes compatibility matrix
- External Secrets Operator support policy and upgrade guidance
- ingress-nginx support matrix and retirement notice
- Metrics Server compatibility and Helm chart values
- kube-state-metrics chart metadata
