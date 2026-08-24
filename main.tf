/**
 * # Why
 *
 * To spin up complete eks with all necessary components.
 * Those include:
 * - vpc (NOTE: the vpc submodule moved into separate repo https://github.com/dasmeta/terraform-aws-vpc)
 * - eks cluster
 * - alb ingress controller
 * - fluentbit
 * - external secrets
 * - metrics to cloudwatch
 * - karpenter
 * - keda
 * - linkerd
 * - flagger
 * - external-dns
 * - event-exporter
 *
 * ## Upgrading guide:
 *  - from version >= 2.25.0, some manual actions are required.
 *   This version adds Karpenter support for GPU instance types.
 *   If you are using resource_configs_defaults, you now need to move it under resource_configs_defaults.default.
 *  - from <2.19.0 to >=2.19.0 version needs some manual actions as we upgraded underlying eks module from 18.x.x to 20.x.x,
 *    here you can find needed actions/changes docs and ready scripts which can be used:
 *    docs:
 *      https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-19.0.md
 *      https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-20.0.md
 *    params:
 *      The node group create_launch_template=false and launch_template_name="" pair params have been replaced with use_custom_launch_template=false
 *    scripts:
 *    ```sh
 *     # commands to move some states, run before applying the `terraform apply` for new version
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.kubernetes_config_map_v1_data.aws_auth[0]" "module.<eks-module-name>.module.eks-cluster[0].module.aws_auth_config_map.kubernetes_config_map_v1_data.aws_auth[0]"
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443_webhook\"]"
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443_webhook\"]"
 *     # command to run in case upgrading from <2.14.6 version, run before applying the `terraform apply` for new version
 *     terraform state rm "module.<eks-module-name>.module.autoscaler[0].aws_iam_policy.policy"
 *     # command to run when apply fails to create the existing resource "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
 *     terraform import "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_eks_access_entry.this[\"cluster_creator\"]" "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
 *     # command to apply when secret store fails to be linked, probably there will be need to remove the resource
 *     terraform import "module.secret_store.kubectl_manifest.main" external-secrets.io/v1beta1//SecretStore//app-test//default
 *    ```
 *  - from <2.20.0 to >=2.20.0 version
 *    - in case if karpenter is enabled.
 *      the karpenter chart have been upgraded and CRDs creation have been moved into separate chart and there is need to run following kubectl commands before applying module update:
 *      ```bash
 *      kubectl patch crd ec2nodeclasses.karpenter.k8s.aws -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
 *      kubectl patch crd nodeclaims.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
 *      kubectl patch crd nodepools.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
 *      ```
 *    - the alb ingress/load-balancer controller variables have been moved under one variable set `alb_load_balancer_controller` so you have to change old way passed config(if you have this variables manually passed), here is the moved ones: `enable_alb_ingress_controller`, `enable_waf_for_alb`
 *  - from <2.21.0 to >=2.21.0 version
 *    - this version upgrade brings about all underlying main components updated to latest versions and eks default version 1.30. all core/important components compatibility have been tested with install from scratch and when applying the update over old version, but in any case possibility of issues in custom configured setups. so that make sure you apply the update in dev/stage environments at first and test that all works as expected and then apply for prod/live.
 *    - in case if karpenter is enabled there is some tricky behavior while upgrade.
 *      the karpenter managed spot instances got interrupted more often(this seems related karpenter drift ability and k8s version+ami version update, so that 2 separate waves of change arrive) so that at some upgrade point there even we can have case without any karpenter managed instance(still needs deeper investigation). So make sure:
 *        - to apply the upgrade at the time when no much traffic to website and if possible cool down critical service which have to not be restarted.
 *        - make sure to set PDB on workloads, which will allow to prevent all workload pods be unavailable at certain point.
 *        - also in case if you have pods with annotations `karpenter.sh/do-not-disrupt: "true"` you may be have need to manually disrupt this pods in order to get their karpenter managed nodes be disrupted/recreated as well to get the new eks version. you can use this annotation to also to prevent karpenter to disrupt nodes where we have such pods, this is handy to manually control when an node can be disrupted.
 *    - the default addon coredns have explicitly set default configurations, and this configs available to configure via var.default_addons config. if you have manually set configs for coredns that differ from default ones here in the module then you may need to set/change the coredns configs in module use to not get your custom ones overridden and missing.
 *  - from <2.22.0 to >=2.22.0 version
 *    - we have linkerd integration implemented, so that starting with this version linkerd will be enabled by default.
 *    - if the linkerd had been deployed before using linkerd cli then you have to disable/uninstall linkerd via cli, here are command to apply
 *      ```sh
 *      linkerd viz uninstall | kubectl delete -f - # to uninstall linkerd viz
 *      linkerd uninstall | kubectl delete -f - # to uninstall linkerd
 *      ```
 *      it is supposed no downtime will be there because of uninstalling/disabling linkerd but recommended to disable(set podAnnotation `linkerd.io/inject: disabled`) at first linkerd on all workloads where we have it enabled and then uninstall it, so that the new module version will bring it back and you can enable(via podAnnotation `linkerd.io/inject: enabled`) back linkerd
 *    - we have also new ability to enable s3-csi driver and get s3 buckets mounted into k8s pod/containers as volume
 *  - from <2.23.0 to >=2.23.0 version
 *    - we have fluentbit and adot disabled by default, so that grafana stack will be used as telemetry data collector and app metrics, check example `eks-with-all-telemetry-to-grafana-stack` for more info on how.
 *    - it still possible to enable fluentbit and adot and have monitoring data collection worked as before by just setting
 *      ```terraform
 *      module "this" {
 *        source  = "dasmeta/eks/aws"
 *        version = ">= 2.23.0"
 *        ....
 *        metrics_exporter = "adot"
 *        fluent_bit_configs = {
 *          enabled = true
 *        }
 *      }
 *      ```
 *    - before disabling adot/fluentbit(what this module version brings) it is recommended to check and disable existing alerting/dashboard in cloudwatch that based on cloudwatch container insights metrics and logs and also inform dev/devops guys that logs/metric are/should-be now available in grafana
 *  - from <2.23.2 to >=2.23.2 version
 *    - the `alarms` variable is not required anymore and the `alarms.sns_topic` also is not required and is by default ""
 *    - the alarms(it is actually one single alarm on ContainerInsights `cluster_failed_node_count` metric) are disabled by default as we have disabled cloudwatch/adot metric exporter
 *    - if you still want to keep alarms enabled with `adot/cloudwatch` exporter you can set the following
 *      ```terraform
 *      module "this" {
 *        source  = "dasmeta/eks/aws"
 *        version = ">= 2.23.2"
 *        ....
 *        metrics_exporter = "adot"
 *        fluent_bit_configs = {
 *          enabled = true
 *        }
 *        alarms = {
 *          enabled = true
 *          sns_topic = "default"
 *        }
 *      }
 *      ```
 *  - from <2.24.0 to >=2.24.0 version
 *    - this version brings the following new ebs csi provisioner attached StorageClasses:
 *
 *        **ebs-gp3**    - new generation general purpose SSD, the default storage class with "gp3" volume types to use with baseline performance 3000 IOPS and 125 MiB/s throughput, gp3 supports up to 1000 MB/s and 16,000 IOPS but there will be need to create separate StorageClass to utilize this with considering that in this case volume size have to satisfy the rule IOPS ≤ 500 × size(GiB) and that extra iops will be charged in separate if exceeds baseline
 *
 *        **ebs-gp2**    - old generation general purpose SSD, this class we create as replacement of aws eks default created "gp2" StorageClass, baseline is 3 IOPS per GiB (3 × volume GiBs) of volume size with minimum 100 IOPS and up to 16,000 IOPS, throughput for ≤ 170 GiB is max ~128 MiB/s; can reaches 250 MiB/s only ≥ 334 GiB; and 170–334 GiB can burst to 250 MiB/s
 *
 *        **ebs-io2-3k, ebs-io2-5k, ebs-io2-8k, ebs-io2-16k, ebs-io2-32k, ebs-io2-64k**  - this ones are predefined set of the "io2" volume type StorageClasses with set/provisioned iops, this are SSDs with provisioned IOPS explicitly (good for latency-sensitive DBs), NOTE: you pay also for the IOPS you set in StorageClass for this volumes (even if you don’t use all of the iops), so make sure you know your ipos requirement when using this classes
 *
 *        **ebs-st1**     - the "st1" type, throughput-optimized HDD, designed for large, sequential I/O (big scans, ETL, log processing, data lakes)
 *
 *        **ebs-sc1**     - the "sc1" type, cold HDD, lowest cost per GiB, lowest baseline throughput; for infrequently accessed, large, sequential data (cold logs, archives)
 *
 *      NOTE: In order to not get default storage classes collision(as before 1.30 version on old created eks clusters we have gp2 storage class annotated as default and we bring new ebs-gp3 one as default) there is need to reset aws auto-created gp2 storage class default tag/annotation, by running the following kubectl script before applying the new change:
 *      ```sh
 *      kubectl annotate sc gp2 storageclass.kubernetes.io/is-default-class- --overwrite
 *      ```
 *      It is supposed tat this will not break already created volumes, even if gp2 StorageClass has not annotated as default the script will pass with no issues, we just have to make sure we do apply the new version change immediately to not have issue for new k8s PVCs which have not explicitly set storageClass and use default. checks show that no major issue if we have two defaults but docs propose to not have and we need to be safe by removing the default-class annotation from gp2 preexist StorageClass
 *
 *  - 2.24.7 version notes
 *    - brings all 3 aws core/default components coredns, vpc-cni/eks-node, kube-proxy into terraform managed addons so that this components will get auto upgraded to newer versions compatible to eks version
 *    - the default of most_recent has been changed from true to false to bring the aws defined default for the addons that we create so that no auto updates for same cluster version will be applied and no surprises, we just take the addon version for eks version we have that aws has marked as default
 *    - got some cleanup of unnecessary tf codes
 *    - have aws-load-balancer-controller helm chart upgraded to new minor compatible version
 *    - do not worry if you do upgrade of eks version and got change that decrease addon version as we have using now not mos recent but the aws default picked one
 *  - from version >= 2.25.0, no manual actions are required. here are what this release brings:
 *    - upgraded eks cluster to 1.33 version
 *    - gateway-api(istio) support added (example how to use can be found in examples/eks-with-istio-gateway-api)
 *    - improved cert-manager implementation by adding cluster-issuer and certificate resources creation and validation based on HTTP01 and DNS01 challenges(example how to used with cloudflare can be found in examples/eks-with-cert-manager)
 *  - from version >= 2.26.0, EKS 1.34 support is added and 1.34 is the new default cluster version.
 *    - This module change does not include live client cluster delivery. Each real cluster upgrade should be handled in a separate delivery ticket with environment-specific validation and rollback planning.
 *    - EKS 1.33 standard support ends on 2026-07-29 and then enters charged extended support. EKS 1.34 standard support ends on 2026-12-02.
 *    - EKS 1.34 has no Amazon Linux 2 optimized AMI. The module defaults for managed node groups already use AL2023, but any consumer override using AL2 must be migrated before the cluster upgrade (separate, unrelated change, out of scope here).
 *    - Components intentionally left unchanged because current defaults already support EKS 1.34 or are selected dynamically from `cluster_version`: terraform-aws-eks v20.x, AWS Load Balancer Controller (root's `alb_load_balancer_controller.chart.version` default, tracked separately from this EKS version change), Karpenter 1.9.0, cert-manager 1.20.0, AWS managed addons such as coredns/vpc-cni/kube-proxy/EBS/S3/ADOT, and node-problem-detector. Broader refreshes for those tools should be separate from this EKS version change.
 *    - Deprecated/removed API review: no module-owned Kubernetes core API removed in 1.34 was found. CRD-owned APIs still depend on their operators. External Secrets examples have been updated to `external-secrets.io/v1`; consumer-owned manifests should also be checked for `storage.k8s.io/v1beta1` VolumeAttributesClass usage, deprecated AppArmor annotations, and manual kubelet `--cgroup-driver` configuration.
 *
 *    ### 1.33 -> 1.34 upgrade runbook (existing clusters only; new clusters can start straight on 1.34, no staging needed)
 *    Each stage below is exactly one `terraform apply` (Stage 2 is the exception: it applies consumer-level manifest changes outside this module, over one or more applies, all under the same intent). Do not combine two stages' config changes into a single apply. Every stage lists an explicit exit criteria; all of it must be true before starting the next stage. If a stage fails verification, revert that stage's own config change and re-apply rather than proceeding.
 *
 *    Preconditions (check once, before Stage 1): no node group overrides pin the AL2 AMI type; PodDisruptionBudgets exist for workloads that must not go fully unavailable during rollouts; if Linkerd is enabled and traffic-critical, read Stage 4 fully before starting, it is the most operationally involved stage.
 *
 *    1. Adopt the module version, hold the control plane and both API-breaking components at their pre-upgrade behavior.
 *       - Goal: pick up every EKS 1.34-safe tooling default (Autoscaler, Metrics Server, KEDA, kube-state-metrics, ingress-nginx) in one apply, while explicitly holding the three things that can break something (`cluster_version`, External Secrets, Linkerd) at their old, known-good behavior.
 *       - Action: bump the module to `>= 2.26.0` and explicitly set the pins below (omit the `linkerd` block entirely if `linkerd.enabled = false`):
 *         ```terraform
 *         module "this" {
 *           source  = "dasmeta/eks/aws"
 *           version = ">= 2.26.0"
 *
 *           # Keep pinned through Stage 4. Move to "1.34" only in Stage 5.
 *           cluster_version = "1.33"
 *
 *           # Bridge version: serves both v1beta1 and v1. Remove in Stage 3.
 *           external_secrets_chart_version = "0.16.2"
 *
 *           # Old chart line. Remove (or set to module defaults) in Stage 4.
 *           linkerd = {
 *             enabled            = true
 *             chart_repository   = "https://helm.linkerd.io/stable"
 *             crds_chart_version = "1.8.0"
 *             chart_version      = "1.16.11"
 *             viz_chart_version  = "30.12.11"
 *           }
 *         }
 *         ```
 *         Apply.
 *       - Known failure mode: on clusters whose External Secrets install predates the `v1alpha1` -> `v1beta1` CRD transition, this apply can fail with `CustomResourceDefinition ... is invalid: status.storedVersions[0]: Invalid value: "v1alpha1": missing from spec.versions`. This is Kubernetes refusing to drop a version from a CRD's `spec.versions` while it is still listed in that CRD's `status.storedVersions`, regardless of whether any live object actually uses it; it is pre-existing cluster state, not a sign of a bad config, and would block any External Secrets chart bump on that cluster. Fix before retrying the apply:
 *         ```sh
 *         # 1. Confirm the stale entry (compare against spec.versions in the same output)
 *         kubectl get crd clustersecretstores.external-secrets.io externalsecrets.external-secrets.io secretstores.external-secrets.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.storedVersions}{"\n"}{end}'
 *
 *         # 2. Re-persist existing objects so etcd re-encodes them under the current storage version (content unchanged; clustersecretstores is cluster-scoped, no -A)
 *         kubectl get clustersecretstores.external-secrets.io -o json | kubectl replace -f -
 *         kubectl get secretstores.external-secrets.io -A -o json | kubectl replace -f -
 *         kubectl get externalsecrets.external-secrets.io -A -o json | kubectl replace -f -
 *
 *         # 3. Patch storedVersions to drop v1alpha1, keeping whatever else step 1 showed (usually just v1beta1)
 *         kubectl patch crd clustersecretstores.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
 *         kubectl patch crd externalsecrets.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
 *         kubectl patch crd secretstores.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
 *         ```
 *         Then retry the apply from this stage.
 *       - Verify: apply completes clean; `cluster_version` unchanged (cluster still reports 1.33); Autoscaler/Metrics Server/KEDA/kube-state-metrics/ingress-nginx pods `Running` on their new versions; the External Secrets operator pod is still running the 0.16.2 image; Linkerd control plane/proxies are untouched (still the old stable chart, no pod restarts on meshed workloads).
 *       - Exit criteria: all pods from the tools bumped in this stage are `Ready`; nothing else drifted.
 *    2. Migrate External Secrets manifests to `v1` (operator still on the 0.16.2 bridge from Stage 1).
 *       - Goal: move every ExternalSecret/SecretStore/ClusterSecretStore-consuming config to the `v1` API while the operator still serves both APIs, so there is a safe rollback window if something doesn't reconcile.
 *       - Action (consumer-level, not this module): set `external_secrets_api_version = "external-secrets.io/v1"` on every `external-secret-store` module call, and update `externalSecretsApiVersion: external-secrets.io/v1` in the `values.yaml` of any chart that renders ExternalSecret/SecretStore manifests. Apply each affected stack.
 *       - Known failure mode: `helm upgrade` on a chart that renders an ExternalSecret/SecretStore can fail with `UPGRADE FAILED: unable to build kubernetes objects from current release manifest: ... no matches for kind "ExternalSecret" in version "external-secrets.io/v1alpha1", ensure CRDs are installed first`, even though the upgrade itself is only changing the apiVersion forward. Helm computes upgrades via a three-way merge, which needs the REST mapping for whatever apiVersion is recorded in that release's *previous* stored manifest (still `v1alpha1` before this migration); once the CRD stops serving `v1alpha1`, that lookup fails and Helm refuses to proceed with the upgrade at all. This is a Helm release-history problem, not a live cluster or config problem, and it blocks any further `helm upgrade` of that release, not just this one. Fix with the [`helm-mapkubeapis`](https://github.com/helm/helm-mapkubeapis) plugin, which rewrites the deprecated apiVersion recorded in Helm's own release history (it does not touch any live object, so the running ExternalSecret and the Kubernetes Secret it owns are unaffected):
 *         ```sh
 *         helm plugin install https://github.com/helm/helm-mapkubeapis
 *
 *         cat > /tmp/eso-mapkubeapis.yaml <<EOF
 *         mappings:
 *           - deprecatedAPI: |
 *               apiVersion: external-secrets.io/v1alpha1
 *               kind: ExternalSecret
 *             newAPI: |
 *               apiVersion: external-secrets.io/v1
 *               kind: ExternalSecret
 *             deprecatedInVersion: "v1.0"
 *             removedInVersion: "v1.0"
 *         EOF
 *
 *         helm mapkubeapis <release-name> -n <namespace> --mapfile /tmp/eso-mapkubeapis.yaml
 *         ```
 *         `deprecatedInVersion`/`removedInVersion` normally hold the Kubernetes version an API was deprecated/removed in, used by the plugin's built-in core-API mappings; External Secrets is a third-party CRD with no such Kubernetes-version tie-in, and leaving these blank makes the plugin fail with `Failed to get the deprecated or removed Kubernetes version for API`. Setting both to a version trivially below any real cluster (e.g. `v1.0`) makes the plugin always treat the mapping as applicable. Retry the `helm upgrade` after running this; add a second `mappings` entry with `kind: SecretStore` (and `ClusterSecretStore` if used) if those hit the same error.
 *       - Verify: `kubectl get externalsecret,secretstore,clustersecretstore -A -o jsonpath='{.items[*].apiVersion}'` shows only `external-secrets.io/v1`; `kubectl get externalsecret -A` shows `SecretSynced`/`Ready=True` for all objects; the resulting Kubernetes Secret values are unchanged from before the migration.
 *       - Exit criteria: zero `external-secrets.io/v1beta1` objects remain in the cluster; every ExternalSecret is synced under `v1`.
 *    3. Complete the External Secrets Operator upgrade.
 *       - Goal: move the operator itself off the bridge version onto the module's real default.
 *       - Action: remove `external_secrets_chart_version = "0.16.2"` from the module call (or set it explicitly to `"2.8.0"`). Apply.
 *       - Verify: the operator pod is running the new chart's image; `kubectl get externalsecret -A` still shows `SecretSynced`/`Ready=True` for everything.
 *       - Exit criteria: operator on 2.8.0+ (v1-only line), all secrets still syncing. This stage is independent of Stage 4 and may run before, after, or in parallel with it, but both must complete before Stage 5.
 *    4. Migrate Linkerd (skip entirely if `linkerd.enabled = false`).
 *       - Goal: move the mesh off the unsupported stable-2.14 line onto the edge 2025.10.7 line supported on EKS 1.34, before the control plane moves.
 *       - Precondition: `linkerd check` and `linkerd check --proxy` pass clean against the current (old) install.
 *       - Action: remove the `linkerd` override block added in Stage 1 (or set it explicitly to the module defaults: edge repo, `2025.10.7` for all three chart versions). Apply. The module's `helm_release` dependency chain (`linkerd-crds` -> `linkerd-control-plane` -> `linkerd-viz`) installs/upgrades those three in that order within this single apply; do not attempt to stage CRDs/control-plane/viz across separate applies pointed at different repositories, the module shares one `chart_repository` across all three.
 *       - Verify: `linkerd check` and `linkerd check --proxy` pass against the new control plane. Existing meshed workloads' sidecars are still the OLD proxy version at this point (they only pick up the new proxy on their next pod restart) — this is expected and safe for a bounded version-skew window, not a stalled migration.
 *       - Follow-up (workload-level, outside this module): restart meshed workloads gradually, namespace by namespace or deployment by deployment rather than a single cluster-wide rollout, so each batch re-injects the new proxy version. Check traffic/error metrics after each batch before restarting the next.
 *       - Exit criteria: `linkerd check --proxy` reports every meshed pod on the new proxy version; traffic metrics healthy across all batches.
 *    5. Upgrade the EKS control plane to 1.34.
 *       - Precondition: Stage 3 and Stage 4 (if applicable) both met their exit criteria; all tooling from Stage 1 still healthy.
 *       - Action: set `cluster_version = "1.34"` (or remove the pin entirely, 1.34 is the module default). Apply.
 *       - Verify: `aws eks describe-cluster --name <cluster> --query cluster.version` returns `1.34`; `kubectl get nodes -o wide` shows nodes on a `1.34.x` kubelet version; `aws eks describe-addon` reports coredns/vpc-cni/kube-proxy/EBS/S3/ADOT as `ACTIVE`/healthy; all tooling verified in earlier stages is still healthy post-upgrade.
 *       - Exit criteria: cluster and all node groups report 1.34; all addons `ACTIVE`; no `CrashLoopBackOff` across kube-system or tooling namespaces. Upgrade complete.
 *  - from version >= 2.30.0, the AWS Load Balancer Controller's IAM identity is wired before its pods start. **No configuration change is required; expect the controller to roll once on the first apply.**
 *    - The problem this fixes: on a fresh install the controller could start before its IAM policy attachment (or, in `pod_identity_association` mode, before its Pod Identity association) existed. The controller receives credentials only at pod start - IRSA binds the annotated service account into the projected token at pod creation, Pod Identity injects the credential environment variables at admission - so a pod that started too early never recovered. The symptom was an Ingress stuck reporting `AccessDenied` on calls such as `elasticloadbalancing:DescribeLoadBalancers` while the policy was visibly attached to the role, cleared only by restarting the controller pods.
 *    - What changes: the role, the policy attachment and the Pod Identity association are now all created before the Helm release; the association no longer depends on the release; a short wait absorbs IAM/STS eventual consistency; and the identity is stamped onto the controller pod template so a later identity change rolls the deployment instead of leaving stale credentials in a running pod.
 *    - On upgrade: the added pod annotation changes the pod template, so the controller deployment rolls once. This is brief and self-healing, and it also clears any controller currently stuck on bad credentials. No resource is replaced and no input is removed.
 *    - New provider requirement: the submodule now declares `hashicorp/time ~> 0.9` for the propagation wait. Run `terraform init -upgrade` to refresh your lock file. The provider needs no configuration.
 *    - The wait defaults to 15 seconds on a fresh install and does not recur on applies that leave the identity unchanged. To opt out entirely:
 *      ```terraform
 *      alb_load_balancer_controller = {
 *        iam = {
 *          propagation_delay = "0s"
 *        }
 *      }
 *      ```
 *
 *  - from version >= 2.28.0, the linkerd-crds chart installs the Gateway API CRDs by default, and the dasmeta chart pins used across `examples/` are refreshed.
 *    - `linkerd.configs_crds.installGatewayAPI` now defaults to `true`. The upstream linkerd-crds chart ships it as `false`, so on an existing cluster this apply **creates the Gateway API CRDs** (`httproutes` and `grpcroutes`, plus `tlsroutes`/`tcproutes` depending on the chart's `enable*Routes` values, all under `gateway.networking.k8s.io`).
 *    - Action is required only if something else in the cluster already owns those CRDs - an Istio or Gateway API controller install, or a separate `gateway-api` chart. Two components managing the same CRDs will fight over them. In that case set the value off explicitly:
 *      ```terraform
 *      linkerd = {
 *        configs_crds = {
 *          installGatewayAPI = false
 *        }
 *      }
 *      ```
 *    - No action is needed where Linkerd is the only Gateway API consumer, or where `linkerd.enabled = false`.
 *    - `examples/` now pin `dasmeta/base` `0.3.32`, and the `namespaces-and-docker-auth` submodule defaults to chart `0.1.3`. Both chart releases default their generated External Secrets resources to `external-secrets.io/v1`; see the chart release notes for the operator requirement and the per-release override.
 *
 *  - from <2.28.0 to >=2.28.0 version, External Secrets moves off IAM users and static access keys onto EKS Pod Identity with IAM role chaining. **This is a two-repository change: the EKS module and every `external-secret-store` call must both be upgraded, in that order.** Read this whole entry before starting.
 *    - What changes: the controller now runs with an EKS Pod Identity association instead of reading credentials from a Kubernetes Secret. It holds no Secrets Manager access itself; it may only `sts:AssumeRole` the per-store roles (`external-secrets-store-*`) created by the `external-secret-store` module, and each of those is scoped to its own `secret:<store-name>*` prefix. The IAM user, its access keys and the `<store>-awssm-secret` Kubernetes Secret are destroyed by this upgrade, which is the intent of the change. The `eks-pod-identity-agent` addon is now installed by default, since a Pod Identity association delivers nothing without it.
 *    - The Helm release moves from the `terraform-module/release/helm` wrapper to a plain `helm_release`. The module carries a `moved` block for this, so the release is re-pointed in state rather than destroyed and recreated. Do not `terraform state rm` anything to "clean up" the old address; that is what causes an uninstall.
 *
 *    **Step 1 - upgrade the EKS module.** Bump the module version and apply. The controller role, its `sts:AssumeRole` grant on `external-secrets-store-*`, the Pod Identity association and the agent addon are all created here. Stores still authenticate with their old static keys at this point and keep working, so this step is safe on its own.
 *
 *    **Step 2 - upgrade every `external-secret-store` call** to `dasmeta/modules/aws//modules/external-secret-store` >= 2.20.0 and wire it to the EKS module's output. `controller_role_arn` is now required; `store_role_name_prefix` must match on both sides or the controller's wildcard `sts:AssumeRole` grant will not cover the store's role:
 *      ```hcl
 *      module "secret_store" {
 *        source  = "dasmeta/modules/aws//modules/external-secret-store"
 *        version = ">= 2.20.0"
 *
 *        name                         = "app/prod"
 *        namespace                    = "prod"
 *        external_secrets_api_version = "external-secrets.io/v1"
 *
 *        controller_role_arn    = module.eks.external_secrets.controller_role_arn
 *        store_role_name_prefix = module.eks.external_secrets.store_role_name_prefix
 *
 *        depends_on = [module.eks]
 *      }
 *      ```
 *      Removed inputs: `create_user`, `aws_access_key_id`, `aws_access_secret`, `aws_role_arn` and `controller`. Applying this destroys the store's IAM user, access key and `<store>-awssm-secret` Secret, and rewrites the `SecretStore` to use `spec.provider.aws.role`. The `SecretStore` object keeps its address, so it is updated in place rather than recreated.
 *
 *    **Step 3 - confirm the controller picked up its new identity.** EKS Pod Identity delivers credentials through environment variables (`AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`) injected into a pod **at admission time**, when the pod is created. Pods already running before the association existed never receive them, their AWS SDK falls back to the node instance role, and every store assume-role call fails with `AccessDenied`. Neither the association nor a Helm values change restarts those pods on its own, so the module stamps the controller's role ARN onto all three pod templates as an annotation; creating or changing the identity therefore rolls the deployments and the replacement pods get the credentials injected. If sync is still failing right after the apply, restart them by hand:
 *      ```sh
 *      kubectl rollout restart deploy -n kube-system external-secrets external-secrets-webhook external-secrets-cert-controller
 *      kubectl rollout status  deploy -n kube-system external-secrets --timeout=180s
 *      ```
 *
 *    **Validation - run this after Step 2/3 and treat it as the exit criteria.** Existing Kubernetes Secrets keep their last synced values when sync breaks, so a broken store looks healthy from the workload side; the checks below force the question rather than relying on pods looking fine:
 *      ```sh
 *      # 1. Every store and secret reports ready. Any False/SecretSyncedError here is a failure.
 *      kubectl get clustersecretstore,secretstore -A
 *      kubectl get externalsecret -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,REASON:.status.conditions[0].reason
 *
 *      # 2. No assume-role or permission errors in the controller.
 *      kubectl logs -n kube-system deploy/external-secrets --tail=200 | grep -iE 'denied|assume|forbidden|error' || echo "clean"
 *
 *      # 3. The static-credential path is really gone (expect NotFound for each store).
 *      kubectl get secret -A | grep awssm-secret || echo "no static key secrets remain - expected"
 *
 *      # 4. Prove a live re-sync actually works rather than trusting cached values: force one
 *      #    ExternalSecret to refetch and confirm it goes Ready again.
 *      kubectl annotate externalsecret <name> -n <ns> force-sync="$(date +%s)" --overwrite
 *      kubectl get externalsecret <name> -n <ns> -w   # expect SecretSynced, Ready=True
 *
 *      # 5. End-to-end: change a value in Secrets Manager and confirm it lands in the Secret.
 *      kubectl get secret <target-secret> -n <ns> -o jsonpath='{.data.<KEY>}' | base64 -d
 *      ```
 *      Step 4 is the one that matters most: a store whose credentials are broken keeps serving the previously synced Secret indefinitely, so only a forced refetch distinguishes "working" from "stale".
 *    - If it still fails, check in this order: the `eks-pod-identity-agent` pods are running (`kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent`); `store_role_name_prefix` matches on both the EKS module and every `external-secret-store` call; the store role's `secret:<name>*` scope actually covers the secret being read (a store named `app/prod` cannot read `app/production-extra` only by luck of prefix, but it also cannot read `other/prod`); and the controller pods were actually recreated after the association appeared (`kubectl get pod -n kube-system -l app.kubernetes.io/name=external-secrets -o jsonpath='{.items[*].spec.containers[*].env[?(@.name=="AWS_CONTAINER_CREDENTIALS_FULL_URI")].name}'` should print the variable name, not empty).
 *
 * ## How to run
 * ```hcl
 * data "aws_availability_zones" "available" {}
 *
 * locals {
 *    cluster_endpoint_public_access = true
 *    cluster_enabled_log_types = ["audit"]
 *  vpc = {
 *    create = {
 *      name = "dev"
 *      availability_zones = data.aws_availability_zones.available.names
 *      private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
 *      public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
 *      cidr               = "172.16.0.0/16"
 *      public_subnet_tags = {
 *    "kubernetes.io/cluster/dev" = "shared"
 *    "kubernetes.io/role/elb"    = "1"
 *  }
 *  private_subnet_tags = {
 *    "kubernetes.io/cluster/dev"       = "shared"
 *    "kubernetes.io/role/internal-elb" = "1"
 *  }
 *    }
 *  }
 *   cluster_name = "your-cluster-name-goes-here"
 *  fluent_bit_name = "fluent-bit"
 *  log_group_name  = "fluent-bit-cloudwatch-env"
 * }
 *
 *
 * #(Basic usage with example of using already created VPC)
 * data "aws_availability_zones" "available" {}
 *
 * locals {
 *    cluster_endpoint_public_access = true
 *    cluster_enabled_log_types = ["audit"]
 *
 *  vpc = {
 *    link = {
 *      id = "vpc-1234"
 *      private_subnet_ids = ["subnet-1", "subnet-2"]
 *    }
 *  }
 *   cluster_name = "your-cluster-name-goes-here"
 *  fluent_bit_name = "fluent-bit"
 *  log_group_name  = "fluent-bit-cloudwatch-env"
 * }
 *
 * # Minimum
 *
 * module "cluster_min" {
 *  source  = "dasmeta/eks/aws"
 *  version = "0.1.1"
 *
 *  cluster_name        = local.cluster_name
 *  users               = local.users
 *
 *  vpc = {
 *    link = {
 *      id = "vpc-1234"
 *      private_subnet_ids = ["subnet-1", "subnet-2"]
 *    }
 *  }
 *
 * }
 *
 * # Max @TODO: the max param passing setup needs to be checked/fixed
 *
 * module "cluster_max" {
 *  source  = "dasmeta/eks/aws"
 *  version = "0.1.1"
 *
 *  ### VPC
 *  vpc = {
 *    create = {
 *      name = "dev"
 *     availability_zones = data.aws_availability_zones.available.names
 *     private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
 *     public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
 *     cidr               = "172.16.0.0/16"
 *     public_subnet_tags = {
 *   "kubernetes.io/cluster/dev" = "shared"
 *   "kubernetes.io/role/elb"    = "1"
 *  }
 *  private_subnet_tags = {
 *    "kubernetes.io/cluster/dev"       = "shared"
 *    "kubernetes.io/role/internal-elb" = "1"
 *  }
 *    }
 *  }
 *
 *  cluster_enabled_log_types = local.cluster_enabled_log_types
 *  cluster_endpoint_public_access = local.cluster_endpoint_public_access
 *
 *  ### EKS
 *  cluster_name          = local.cluster_name
 *  manage_aws_auth       = true
 *
 *  # IAM users username and group. By default value is ["system:masters"]
 *  user = [
 *          {
 *            username = "devops1"
 *            group    = ["system:masters"]
 *          },
 *          {
 *            username = "devops2"
 *            group    = ["system:kube-scheduler"]
 *          },
 *          {
 *            username = "devops3"
 *          }
 *  ]
 *
 *  # You can create node use node_group when you create node in specific subnet zone.(Note. This Case Ec2 Instance havn't specific name).
 *  # Other case you can use worker_group variable.
 *
 *  node_groups = {
 *    example =  {
 *      name  = "nodegroup"
 *      name-prefix     = "nodegroup"
 *      additional_tags = {
 *          "Name"      = "node"
 *          "ExtraTag"  = "ExtraTag"
 *      }
 *
 *      instance_type   = "t3.xlarge"
 *      max_size    = 1
 *      disk_size       = 50
 *      create_launch_template = false
 *      subnet = ["subnet_id"]
 *    }
 * }
 *
 * node_groups_default = {
 *     disk_size      = 50
 *     instance_types = ["t3.medium"]
 *   }
 *
 * worker_groups = {
 *   default = {
 *     name              = "nodes"
 *     instance_type     = "t3.xlarge"
 *     asg_max_size      = 3
 *     root_volume_size  = 50
 *   }
 * }
 *
 *  workers_group_defaults = {
 *    launch_template_use_name_prefix = true
 *    launch_template_name            = "default"
 *    root_volume_type                = "gp3"
 *    root_volume_size                = 50
 *  }
 *
 *  ### FLUENT-BIT
 *  fluent_bit_name = local.fluent_bit_name
 *  log_group_name  = local.log_group_name
 *
 *  # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
 *  ### METRICS-SERVER
 *  # enable_metrics_server = false
 *  metrics_server_name     = "metrics-server"
 * }
 * ```
 *
 * ## karpenter enabled
 * ### NOTES:
 * ###  - enabling karpenter automatically disables cluster auto-scaler, starting from 2.30.0 version karpenter is enabled by default
 * ###  - if vpc have been created externally(not inside this module) then you may need to set the following tags on private subnets `karpenter.sh/discovery=<cluster-name>`
 * ###  - then enabling karpenter on existing old cluster there is possibility to see cycle-dependency error, to overcome this you need at first to apply main eks module change (`terraform apply --target "module.<eks-module-name>.module.eks-cluster"`) and then rest of cluster-autoloader destroy and karpenter install ones
 * ###  - when destroying cluster which have karpenter enabled there is possibility of failure on karpenter resource removal, you need to run destruction one more time to get it complete
 * ###  - in order to be able to use spot instances you may need to create AWSServiceRoleForEC2Spot IAM role on aws account(TODO: check and create this role on account module automatically), here is the doc: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/service-linked-roles-spot-instance-requests.html , otherwise karpenter created `nodeclaim` kubernetes resource will show AuthFailure.ServiceLinkedRoleCreationNotPermitted error
 * ###  - karpenter is designed to keep nodes as cheep as possible to that by default it can dynamically disrupt/collocate nodes, even on-demand ones. So in order to control the process in specific cases use following options: setting `karpenter.sh/do-not-disrupt: "true"` for pod (or this can be set also on node) prevents karpenter to disrupt the node where pod runs(be aware to manually drain such nodes when you do eks version upgrades), also pods PDB(PodDisruptionBudget) option can be used as karpenter respects this, the node-pools disruption params also can be used to create more advanced logics(my default `disruption = { consolidationPolicy="WhenEmptyOrUnderutilized", consolidateAfter="3m", budgets={nodes : "10%"}}`)
 *
 * ```terraform
 * module "eks" {
 *  source  = "dasmeta/eks/aws"
 *  version = "3.x.x"
 *  .....
 *  karpenter = {
 *   enabled = true
 *   # Optional: defaults are replicas=2 and priorityClassName="high".
 *   # Set only if you want to override defaults explicitly.
 *   # configs = {
 *   #   replicas          = 2
 *   #   priorityClassName = "high"
 *   # }
 *   resource_configs_defaults = { # this is optional param, look into karpenter submodule to get available defaults
 *     limits = {
 *       cpu = 11 # the default is 10 and we can add limit restrictions on memory also
 *     }
 *   }
 *   resource_configs = {
 *     nodePools = {
 *       general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
 *     }
 *   }
 *  }
 *  .....
 * }
 * ```
 **/
module "vpc" {
  source  = "dasmeta/vpc/aws"
  version = "1.0.1"

  count = try(var.vpc.create.name) != null ? 1 : 0

  name               = var.vpc.create.name
  availability_zones = var.vpc.create.availability_zones
  cidr               = var.vpc.create.cidr
  private_subnets    = var.vpc.create.private_subnets
  public_subnets     = var.vpc.create.public_subnets
  public_subnet_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = 1
    },
    var.vpc.create.public_subnet_tags
  )
  private_subnet_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = 1
    },
    var.vpc.create.private_subnet_tags
  )
}

module "eks-cluster" {
  source = "./modules/eks"
  count  = var.create ? 1 : 0

  region = local.region

  cluster_name = var.cluster_name
  vpc_id       = local.vpc_id
  subnets      = local.subnet_ids

  users                                = var.users
  node_groups                          = var.node_groups
  node_groups_default                  = var.node_groups_default
  worker_groups                        = var.worker_groups
  workers_group_defaults               = var.workers_group_defaults
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_version                      = var.cluster_version
  map_roles                            = var.map_roles
  node_security_group_additional_rules = var.node_security_group_additional_rules
  cluster_addons                       = local.cluster_addons
  enable_autoscaling_group_metrics     = var.enable_autoscaling_group_metrics
  tags = merge(
    var.tags,
    local.cluster_autoscaler_enabled ? {
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    } : {},
    var.karpenter.enabled ? { "karpenter.sh/discovery" = "${var.cluster_name}" } : {}
  )
}

# we have this empty module here just for setting aws code components dependencies in one place to use in other dependant module/resource
module "eks-core-components" {
  source  = "dasmeta/empty/null"
  version = "1.2.2"

  depends_on = [module.eks-cluster[0].host, module.eks-cluster[0].oidc_provider_arn, module.eks-cluster[0].eks_managed_node_groups]
}

# for setting dependency in modules which have also dependency on load balancer, there is some ability related aws load balancer webhooks and option `enableServiceMutatorWebhook = "false"` so that sometime setups other helm setup in eks batch setup may fail waiting for alb controller webhooks be ready, TODO: in case of continues issues in future consider to set enable `enableServiceMutatorWebhook = "false"` option setting in alb controller
module "eks-core-components-and-alb" {
  source  = "dasmeta/empty/null"
  version = "1.2.2"

  depends_on = [module.eks-core-components, module.alb-ingress-controller]
}


module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  count = var.metrics_exporter == "cloudwatch" ? 1 : 0

  account_id = local.account_id
  region     = local.region

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  cluster_name                = var.cluster_name

  depends_on = [module.eks-core-components]
}

module "metrics-server" {
  source = "./modules/metrics-server"

  count = var.create ? 1 : 0

  name          = var.metrics_server_name != "" ? var.metrics_server_name : "${module.eks-cluster[0].cluster_name}-metrics-server"
  chart_version = var.metrics_server_chart_version

  depends_on = [module.eks-core-components-and-alb]
}

module "external-secrets" {
  source = "./modules/external-secrets"

  count = var.create && local.external_secrets_enabled ? 1 : 0

  cluster_name = var.cluster_name
  namespace    = local.external_secrets_namespace
  chart = {
    name       = var.external_secrets.chart.name
    repository = var.external_secrets.chart.repository
    version    = local.external_secrets_chart_version
  }
  image                     = var.external_secrets.image
  attachment_method         = var.external_secrets.iam.attachment_method
  iam_role_name             = var.external_secrets.iam.role_name
  store_role_name_prefix    = var.external_secrets.iam.store_role_name_prefix
  service_account_name      = var.external_secrets.service_account_name
  values                    = var.external_secrets.values
  extra_values              = var.external_secrets.extra_values
  region                    = local.region
  oidc_provider_arn         = module.eks-cluster[0].oidc_provider_arn
  resolve_oidc_from_cluster = false # oidc_provider_arn is always supplied above; avoids an unknown-at-plan count on first cluster creation

  depends_on = [module.eks-core-components-and-alb]
}

module "sso-rbac" {
  source = "./modules/sso-rbac"

  count = var.enable_sso_rbac && var.create ? 1 : 0

  account_id = local.account_id

  roles      = var.roles
  bindings   = var.bindings
  eks_module = module.eks-cluster[0].eks_module

  depends_on = [module.eks-core-components]
}

module "efs-csi-driver" {
  source = "./modules/efs-csi"

  count            = var.enable_efs_driver ? 1 : 0
  cluster_name     = var.cluster_name
  efs_id           = var.efs_id
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  storage_classes  = var.efs_storage_classes
  region           = local.region

  depends_on = [module.eks-core-components]
}

# cert-manager module - combines Helm chart installation and resource creation
module "cert-manager" {
  count = var.create && (var.create_cert_manager || var.metrics_exporter == "adot") ? 1 : 0

  source = "./modules/cert-manager"

  chart_version = var.cert_manager_chart_version
  namespace     = var.cert_manager.namespace
  atomic        = var.cert_manager.atomic
  configs       = var.cert_manager.configs
  extra_configs = var.cert_manager.extra_configs

  cluster_name      = var.cluster_name
  oidc_provider_arn = try(module.eks-cluster[0].oidc_provider_arn, "")
  region            = local.region

  cluster_issuers   = try(var.cert_manager.resources.cluster_issuers, [])
  dns01_secret_data = try(var.cert_manager.resources.dns01_secret_data, {})
  certificates      = try(var.cert_manager.resources.certificates, [])

  depends_on = [module.eks-core-components-and-alb]
}

resource "helm_release" "kube-state-metrics" {
  count = var.enable_kube_state_metrics ? 1 : 0

  name             = "kube-state-metrics"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-state-metrics"
  namespace        = "kube-system"
  version          = var.kube_state_metrics_chart_version
  create_namespace = false
  atomic           = true

  set_list {
    name = "metricAllowlist"
    value = concat(var.prometheus_metrics, [
      "kube_deployment_spec_replicas",
      "kube_deployment_status_replicas_available"
    ])
  }

  depends_on = [module.eks-core-components]
}

module "autoscaler" {
  source = "./modules/autoscaler"

  count                    = local.cluster_autoscaler_enabled ? 1 : 0
  cluster_name             = var.cluster_name
  cluster_oidc_arn         = module.eks-cluster[0].oidc_provider_arn
  eks_version              = var.cluster_version
  autoscaler_image_patch   = var.autoscaler_image_patch
  scale_down_unneeded_time = var.scale_down_unneeded_time
  requests                 = var.autoscaler_requests
  limits                   = var.autoscaler_limits
  region                   = local.region

  depends_on = [module.eks-core-components]
}

# TODO: The main eks module supports addons, the only thing it needs is iam role to pass, maybe we can create iam role here and pass to main module to create addon and attach the role there
module "ebs-csi" {
  source = "./modules/ebs-csi"

  count            = var.enable_ebs_driver ? 1 : 0
  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  addon_version    = var.ebs_csi_version
  storage_classes  = var.ebs_csi_storage_classes
  region           = local.region

  depends_on = [module.eks-core-components]
}

module "s3-csi" {
  source = "./modules/s3-csi"

  count = var.s3_csi.enabled ? 1 : 0

  cluster_name      = var.cluster_name
  cluster_version   = var.cluster_version
  oidc_provider_arn = module.eks-cluster[0].oidc_provider_arn
  addon_version     = var.s3_csi.addon_version
  s3_buckets        = var.s3_csi.buckets
  configs           = var.s3_csi.configs
  region            = local.region

  depends_on = [module.eks-core-components]
}

module "api-gw-controller" {
  source = "./modules/api-gw"

  count = var.enable_api_gw_controller ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  deploy_region    = var.api_gw_deploy_region
  region           = local.region

  api_gateway_resources = var.api_gateway_resources
  vpc_id                = var.api_gateway_resources[0].vpc_links != null ? module.vpc[0].id : null
  subnet_ids            = var.api_gateway_resources[0].vpc_links != null ? (var.vpc.create.private_subnets != {} ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids) : null

  depends_on = [module.eks-core-components]
}

module "portainer" {
  count = var.enable_portainer ? 1 : 0

  source         = "./modules/portainer"
  host           = var.portainer_config.host
  enable_ingress = var.portainer_config.enable_ingress

  depends_on = [module.eks-core-components]
}

module "external-dns" {
  count = var.create && var.external_dns.enabled ? 1 : 0

  source                     = "./modules/external-dns"
  cluster_name               = var.cluster_name
  oidc_provider_arn          = module.eks-cluster[0].oidc_provider_arn
  region                     = local.region
  enable_gateway_api_sources = var.istio.enabled
  configs                    = var.external_dns.configs

  depends_on = [module.eks-core-components-and-alb, module.istio]
}

module "flagger" {
  count = var.create && var.flagger.enabled ? 1 : 0

  source                     = "./modules/flagger"
  namespace                  = var.flagger.namespace
  configs                    = var.flagger.configs
  metrics_and_alerts_configs = var.flagger.metrics_and_alerts_configs
  enable_loadtester          = var.flagger.enable_loadtester

  depends_on = [module.eks-core-components-and-alb]
}

module "karpenter" {
  count = var.create && var.karpenter.enabled ? 1 : 0

  source                    = "./modules/karpenter"
  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  cluster_endpoint          = module.eks-cluster[0].host
  oidc_provider_arn         = module.eks-cluster[0].oidc_provider_arn
  subnet_ids                = local.subnet_ids
  configs                   = local.karpenter_configs
  resource_configs          = var.karpenter.resource_configs
  resource_configs_defaults = var.karpenter.resource_configs_defaults
  tags                      = var.tags

  depends_on = [module.eks-core-components, module.priority_class]
}

module "namespaces_and_docker_auth" {
  count = var.create && var.namespaces_and_docker_auth.enabled ? 1 : 0

  source            = "./modules/namespaces-and-docker-auth"
  cluster_name      = var.cluster_name
  cluster_endpoint  = module.eks-cluster[0].host
  oidc_provider_arn = module.eks-cluster[0].oidc_provider_arn
  configs           = var.namespaces_and_docker_auth
  region            = local.region

  depends_on = [module.external-secrets, kubernetes_namespace.meta-system]
}

module "linkerd" {
  count = var.create && var.linkerd.enabled ? 1 : 0

  source             = "./modules/linkerd"
  chart_repository   = var.linkerd.chart_repository
  crds_chart_version = var.linkerd.crds_chart_version
  chart_version      = var.linkerd.chart_version
  viz_chart_version  = var.linkerd.viz_chart_version
  configs            = var.linkerd.configs
  configs_crds       = var.linkerd.configs_crds
  configs_viz        = var.linkerd.configs_viz
  crds_create        = var.linkerd.crds_create
  viz_create         = var.linkerd.viz_create

  depends_on = [module.eks-core-components-and-alb]
}

module "istio" {
  source  = "dasmeta/shared/any//modules/istio"
  version = "1.7.9"

  count = var.create && var.istio.enabled ? 1 : 0

  configs = var.istio.configs

  depends_on = [module.eks-core-components-and-alb]
}

module "event_exporter" {
  count = var.create && var.event_exporter.enabled ? 1 : 0

  source  = "./modules/event-exporter"
  configs = var.event_exporter.configs

  depends_on = [module.eks-core-components, kubernetes_namespace.meta-system]
}

module "node_local_dns" {
  count = var.create && var.node_local_dns.enabled ? 1 : 0

  source  = "./modules/node-local-dns"
  configs = var.node_local_dns.configs

  depends_on = [module.eks-core-components]
}

module "kyverno" {
  count = var.create && var.kyverno.enabled ? 1 : 0

  source  = "dasmeta/shared/any//modules/kyverno"
  version = "1.5.0"

  policies        = var.kyverno.policies
  custom_policies = var.kyverno.custom_policies
  extra_configs   = var.kyverno.extra_configs

  depends_on = [module.eks-core-components-and-alb]
}
