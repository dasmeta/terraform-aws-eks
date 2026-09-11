<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Why

To spin up complete eks with all necessary components.
Those include:
- vpc (NOTE: the vpc submodule moved into separate repo https://github.com/dasmeta/terraform-aws-vpc)
- eks cluster
- alb ingress controller
- fluentbit
- external secrets
- metrics to cloudwatch
- karpenter
- keda
- linkerd
- flagger
- external-dns
- event-exporter

## Upgrading guide:
 - from version >= 2.25.0, some manual actions are required.
  This version adds Karpenter support for GPU instance types.
  If you are using resource\_configs\_defaults, you now need to move it under resource\_configs\_defaults.default.
 - from <2.19.0 to >=2.19.0 version needs some manual actions as we upgraded underlying eks module from 18.x.x to 20.x.x,
   here you can find needed actions/changes docs and ready scripts which can be used:
   docs:
     https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-19.0.md
     https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-20.0.md
   params:
     The node group create\_launch\_template=false and launch\_template\_name="" pair params have been replaced with use\_custom\_launch\_template=false
   scripts:
   ```sh
    # commands to move some states, run before applying the `terraform apply` for new version
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.kubernetes_config_map_v1_data.aws_auth[0]" "module.<eks-module-name>.module.eks-cluster[0].module.aws_auth_config_map.kubernetes_config_map_v1_data.aws_auth[0]"
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443_webhook\"]"
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443_webhook\"]"
    # command to run in case upgrading from <2.14.6 version, run before applying the `terraform apply` for new version
    terraform state rm "module.<eks-module-name>.module.autoscaler[0].aws_iam_policy.policy"
    # command to run when apply fails to create the existing resource "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
    terraform import "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_eks_access_entry.this[\"cluster_creator\"]" "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
    # command to apply when secret store fails to be linked, probably there will be need to remove the resource
    terraform import "module.secret_store.kubectl_manifest.main" external-secrets.io/v1beta1//SecretStore//app-test//default
   ```
 - from <2.20.0 to >=2.20.0 version
   - in case if karpenter is enabled.
     the karpenter chart have been upgraded and CRDs creation have been moved into separate chart and there is need to run following kubectl commands before applying module update:
     ```bash
     kubectl patch crd ec2nodeclasses.karpenter.k8s.aws -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     kubectl patch crd nodeclaims.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     kubectl patch crd nodepools.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     ```
   - the alb ingress/load-balancer controller variables have been moved under one variable set `alb_load_balancer_controller` so you have to change old way passed config(if you have this variables manually passed), here is the moved ones: `enable_alb_ingress_controller`, `enable_waf_for_alb`
 - from <2.21.0 to >=2.21.0 version
   - this version upgrade brings about all underlying main components updated to latest versions and eks default version 1.30. all core/important components compatibility have been tested with install from scratch and when applying the update over old version, but in any case possibility of issues in custom configured setups. so that make sure you apply the update in dev/stage environments at first and test that all works as expected and then apply for prod/live.
   - in case if karpenter is enabled there is some tricky behavior while upgrade.
     the karpenter managed spot instances got interrupted more often(this seems related karpenter drift ability and k8s version+ami version update, so that 2 separate waves of change arrive) so that at some upgrade point there even we can have case without any karpenter managed instance(still needs deeper investigation). So make sure:
       - to apply the upgrade at the time when no much traffic to website and if possible cool down critical service which have to not be restarted.
       - make sure to set PDB on workloads, which will allow to prevent all workload pods be unavailable at certain point.
       - also in case if you have pods with annotations `karpenter.sh/do-not-disrupt: "true"` you may be have need to manually disrupt this pods in order to get their karpenter managed nodes be disrupted/recreated as well to get the new eks version. you can use this annotation to also to prevent karpenter to disrupt nodes where we have such pods, this is handy to manually control when an node can be disrupted.
   - the default addon coredns have explicitly set default configurations, and this configs available to configure via var.default\_addons config. if you have manually set configs for coredns that differ from default ones here in the module then you may need to set/change the coredns configs in module use to not get your custom ones overridden and missing.
 - from <2.22.0 to >=2.22.0 version
   - we have linkerd integration implemented, so that starting with this version linkerd will be enabled by default.
   - if the linkerd had been deployed before using linkerd cli then you have to disable/uninstall linkerd via cli, here are command to apply
     ```sh
     linkerd viz uninstall | kubectl delete -f - # to uninstall linkerd viz
     linkerd uninstall | kubectl delete -f - # to uninstall linkerd
     ```
     it is supposed no downtime will be there because of uninstalling/disabling linkerd but recommended to disable(set podAnnotation `linkerd.io/inject: disabled`) at first linkerd on all workloads where we have it enabled and then uninstall it, so that the new module version will bring it back and you can enable(via podAnnotation `linkerd.io/inject: enabled`) back linkerd
   - we have also new ability to enable s3-csi driver and get s3 buckets mounted into k8s pod/containers as volume
 - from <2.23.0 to >=2.23.0 version
   - we have fluentbit and adot disabled by default, so that grafana stack will be used as telemetry data collector and app metrics, check example `eks-with-all-telemetry-to-grafana-stack` for more info on how.
   - it still possible to enable fluentbit and adot and have monitoring data collection worked as before by just setting
     ```terraform
     module "this" {
       source  = "dasmeta/eks/aws"
       version = ">= 2.23.0"
       ....
       metrics_exporter = "adot"
       fluent_bit_configs = {
         enabled = true
       }
     }
     ```
   - before disabling adot/fluentbit(what this module version brings) it is recommended to check and disable existing alerting/dashboard in cloudwatch that based on cloudwatch container insights metrics and logs and also inform dev/devops guys that logs/metric are/should-be now available in grafana
 - from <2.23.2 to >=2.23.2 version
   - the `alarms` variable is not required anymore and the `alarms.sns_topic` also is not required and is by default ""
   - the alarms(it is actually one single alarm on ContainerInsights `cluster_failed_node_count` metric) are disabled by default as we have disabled cloudwatch/adot metric exporter
   - if you still want to keep alarms enabled with `adot/cloudwatch` exporter you can set the following
     ```terraform
     module "this" {
       source  = "dasmeta/eks/aws"
       version = ">= 2.23.2"
       ....
       metrics_exporter = "adot"
       fluent_bit_configs = {
         enabled = true
       }
       alarms = {
         enabled = true
         sns_topic = "default"
       }
     }
     ```
 - from <2.24.0 to >=2.24.0 version
   - this version brings the following new ebs csi provisioner attached StorageClasses:

       **ebs-gp3**    - new generation general purpose SSD, the default storage class with "gp3" volume types to use with baseline performance 3000 IOPS and 125 MiB/s throughput, gp3 supports up to 1000 MB/s and 16,000 IOPS but there will be need to create separate StorageClass to utilize this with considering that in this case volume size have to satisfy the rule IOPS ≤ 500 × size(GiB) and that extra iops will be charged in separate if exceeds baseline

       **ebs-gp2**    - old generation general purpose SSD, this class we create as replacement of aws eks default created "gp2" StorageClass, baseline is 3 IOPS per GiB (3 × volume GiBs) of volume size with minimum 100 IOPS and up to 16,000 IOPS, throughput for ≤ 170 GiB is max ~128 MiB/s; can reaches 250 MiB/s only ≥ 334 GiB; and 170–334 GiB can burst to 250 MiB/s

       **ebs-io2-3k, ebs-io2-5k, ebs-io2-8k, ebs-io2-16k, ebs-io2-32k, ebs-io2-64k**  - this ones are predefined set of the "io2" volume type StorageClasses with set/provisioned iops, this are SSDs with provisioned IOPS explicitly (good for latency-sensitive DBs), NOTE: you pay also for the IOPS you set in StorageClass for this volumes (even if you don’t use all of the iops), so make sure you know your ipos requirement when using this classes

       **ebs-st1**     - the "st1" type, throughput-optimized HDD, designed for large, sequential I/O (big scans, ETL, log processing, data lakes)

       **ebs-sc1**     - the "sc1" type, cold HDD, lowest cost per GiB, lowest baseline throughput; for infrequently accessed, large, sequential data (cold logs, archives)

     NOTE: In order to not get default storage classes collision(as before 1.30 version on old created eks clusters we have gp2 storage class annotated as default and we bring new ebs-gp3 one as default) there is need to reset aws auto-created gp2 storage class default tag/annotation, by running the following kubectl script before applying the new change:
     ```sh
     kubectl annotate sc gp2 storageclass.kubernetes.io/is-default-class- --overwrite
     ```
     It is supposed tat this will not break already created volumes, even if gp2 StorageClass has not annotated as default the script will pass with no issues, we just have to make sure we do apply the new version change immediately to not have issue for new k8s PVCs which have not explicitly set storageClass and use default. checks show that no major issue if we have two defaults but docs propose to not have and we need to be safe by removing the default-class annotation from gp2 preexist StorageClass

 - 2.24.7 version notes
   - brings all 3 aws core/default components coredns, vpc-cni/eks-node, kube-proxy into terraform managed addons so that this components will get auto upgraded to newer versions compatible to eks version
   - the default of most\_recent has been changed from true to false to bring the aws defined default for the addons that we create so that no auto updates for same cluster version will be applied and no surprises, we just take the addon version for eks version we have that aws has marked as default
   - got some cleanup of unnecessary tf codes
   - have aws-load-balancer-controller helm chart upgraded to new minor compatible version
   - do not worry if you do upgrade of eks version and got change that decrease addon version as we have using now not mos recent but the aws default picked one
 - from version >= 2.25.0, no manual actions are required. here are what this release brings:
   - upgraded eks cluster to 1.33 version
   - gateway-api(istio) support added (example how to use can be found in examples/eks-with-istio-gateway-api)
   - improved cert-manager implementation by adding cluster-issuer and certificate resources creation and validation based on HTTP01 and DNS01 challenges(example how to used with cloudflare can be found in examples/eks-with-cert-manager)
 - from version >= 2.26.0, EKS 1.34 support is added and 1.34 is the new default cluster version.
   - This module change does not include live client cluster delivery. Each real cluster upgrade should be handled in a separate delivery ticket with environment-specific validation and rollback planning.
   - EKS 1.33 standard support ends on 2026-07-29 and then enters charged extended support. EKS 1.34 standard support ends on 2026-12-02.
   - EKS 1.34 has no Amazon Linux 2 optimized AMI. The module defaults for managed node groups already use AL2023, but any consumer override using AL2 must be migrated before the cluster upgrade (separate, unrelated change, out of scope here).
   - Components intentionally left unchanged because current defaults already support EKS 1.34 or are selected dynamically from `cluster_version`: terraform-aws-eks v20.x, AWS Load Balancer Controller (root's `alb_load_balancer_controller.chart.version` default, tracked separately from this EKS version change), Karpenter 1.9.0, cert-manager 1.20.0, AWS managed addons such as coredns/vpc-cni/kube-proxy/EBS/S3/ADOT, and node-problem-detector. Broader refreshes for those tools should be separate from this EKS version change.
   - Deprecated/removed API review: no module-owned Kubernetes core API removed in 1.34 was found. CRD-owned APIs still depend on their operators. External Secrets examples have been updated to `external-secrets.io/v1`; consumer-owned manifests should also be checked for `storage.k8s.io/v1beta1` VolumeAttributesClass usage, deprecated AppArmor annotations, and manual kubelet `--cgroup-driver` configuration.

   ### 1.33 -> 1.34 upgrade runbook (existing clusters only; new clusters can start straight on 1.34, no staging needed)
   Each stage below is exactly one `terraform apply` (Stage 2 is the exception: it applies consumer-level manifest changes outside this module, over one or more applies, all under the same intent). Do not combine two stages' config changes into a single apply. Every stage lists an explicit exit criteria; all of it must be true before starting the next stage. If a stage fails verification, revert that stage's own config change and re-apply rather than proceeding.

   Preconditions (check once, before Stage 1): no node group overrides pin the AL2 AMI type; PodDisruptionBudgets exist for workloads that must not go fully unavailable during rollouts; if Linkerd is enabled and traffic-critical, read Stage 4 fully before starting, it is the most operationally involved stage.

   1. Adopt the module version, hold the control plane and both API-breaking components at their pre-upgrade behavior.
      - Goal: pick up every EKS 1.34-safe tooling default (Autoscaler, Metrics Server, KEDA, kube-state-metrics, ingress-nginx) in one apply, while explicitly holding the three things that can break something (`cluster_version`, External Secrets, Linkerd) at their old, known-good behavior.
      - Action: bump the module to `>= 2.26.0` and explicitly set the pins below (omit the `linkerd` block entirely if `linkerd.enabled = false`):
        ```terraform
        module "this" {
          source  = "dasmeta/eks/aws"
          version = ">= 2.26.0"

          # Keep pinned through Stage 4. Move to "1.34" only in Stage 5.
          cluster_version = "1.33"

          # Bridge version: serves both v1beta1 and v1. Remove in Stage 3.
          external_secrets_chart_version = "0.16.2"

          # Old chart line. Remove (or set to module defaults) in Stage 4.
          linkerd = {
            enabled            = true
            chart_repository   = "https://helm.linkerd.io/stable"
            crds_chart_version = "1.8.0"
            chart_version      = "1.16.11"
            viz_chart_version  = "30.12.11"
          }
        }
        ```
        Apply.
      - Known failure mode: on clusters whose External Secrets install predates the `v1alpha1` -> `v1beta1` CRD transition, this apply can fail with `CustomResourceDefinition ... is invalid: status.storedVersions[0]: Invalid value: "v1alpha1": missing from spec.versions`. This is Kubernetes refusing to drop a version from a CRD's `spec.versions` while it is still listed in that CRD's `status.storedVersions`, regardless of whether any live object actually uses it; it is pre-existing cluster state, not a sign of a bad config, and would block any External Secrets chart bump on that cluster. Fix before retrying the apply:
        ```sh
        # 1. Confirm the stale entry (compare against spec.versions in the same output)
        kubectl get crd clustersecretstores.external-secrets.io externalsecrets.external-secrets.io secretstores.external-secrets.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.storedVersions}{"\n"}{end}'

        # 2. Re-persist existing objects so etcd re-encodes them under the current storage version (content unchanged; clustersecretstores is cluster-scoped, no -A)
        kubectl get clustersecretstores.external-secrets.io -o json | kubectl replace -f -
        kubectl get secretstores.external-secrets.io -A -o json | kubectl replace -f -
        kubectl get externalsecrets.external-secrets.io -A -o json | kubectl replace -f -

        # 3. Patch storedVersions to drop v1alpha1, keeping whatever else step 1 showed (usually just v1beta1)
        kubectl patch crd clustersecretstores.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
        kubectl patch crd externalsecrets.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
        kubectl patch crd secretstores.external-secrets.io --subresource=status --type=merge -p '{"status":{"storedVersions":["v1beta1"]}}'
        ```
        Then retry the apply from this stage.
      - Verify: apply completes clean; `cluster_version` unchanged (cluster still reports 1.33); Autoscaler/Metrics Server/KEDA/kube-state-metrics/ingress-nginx pods `Running` on their new versions; the External Secrets operator pod is still running the 0.16.2 image; Linkerd control plane/proxies are untouched (still the old stable chart, no pod restarts on meshed workloads).
      - Exit criteria: all pods from the tools bumped in this stage are `Ready`; nothing else drifted.
   2. Migrate External Secrets manifests to `v1` (operator still on the 0.16.2 bridge from Stage 1).
      - Goal: move every ExternalSecret/SecretStore/ClusterSecretStore-consuming config to the `v1` API while the operator still serves both APIs, so there is a safe rollback window if something doesn't reconcile.
      - Action (consumer-level, not this module): set `external_secrets_api_version = "external-secrets.io/v1"` on every `external-secret-store` module call, and update `externalSecretsApiVersion: external-secrets.io/v1` in the `values.yaml` of any chart that renders ExternalSecret/SecretStore manifests. Apply each affected stack.
      - Known failure mode: `helm upgrade` on a chart that renders an ExternalSecret/SecretStore can fail with `UPGRADE FAILED: unable to build kubernetes objects from current release manifest: ... no matches for kind "ExternalSecret" in version "external-secrets.io/v1alpha1", ensure CRDs are installed first`, even though the upgrade itself is only changing the apiVersion forward. Helm computes upgrades via a three-way merge, which needs the REST mapping for whatever apiVersion is recorded in that release's *previous* stored manifest (still `v1alpha1` before this migration); once the CRD stops serving `v1alpha1`, that lookup fails and Helm refuses to proceed with the upgrade at all. This is a Helm release-history problem, not a live cluster or config problem, and it blocks any further `helm upgrade` of that release, not just this one. Fix with the [`helm-mapkubeapis`](https://github.com/helm/helm-mapkubeapis) plugin, which rewrites the deprecated apiVersion recorded in Helm's own release history (it does not touch any live object, so the running ExternalSecret and the Kubernetes Secret it owns are unaffected):
        ```sh
        helm plugin install https://github.com/helm/helm-mapkubeapis

        cat > /tmp/eso-mapkubeapis.yaml <<EOF
        mappings:
          - deprecatedAPI: |
              apiVersion: external-secrets.io/v1alpha1
              kind: ExternalSecret
            newAPI: |
              apiVersion: external-secrets.io/v1
              kind: ExternalSecret
            deprecatedInVersion: "v1.0"
            removedInVersion: "v1.0"
        EOF

        helm mapkubeapis <release-name> -n <namespace> --mapfile /tmp/eso-mapkubeapis.yaml
        ```
        `deprecatedInVersion`/`removedInVersion` normally hold the Kubernetes version an API was deprecated/removed in, used by the plugin's built-in core-API mappings; External Secrets is a third-party CRD with no such Kubernetes-version tie-in, and leaving these blank makes the plugin fail with `Failed to get the deprecated or removed Kubernetes version for API`. Setting both to a version trivially below any real cluster (e.g. `v1.0`) makes the plugin always treat the mapping as applicable. Retry the `helm upgrade` after running this; add a second `mappings` entry with `kind: SecretStore` (and `ClusterSecretStore` if used) if those hit the same error.
      - Verify: `kubectl get externalsecret,secretstore,clustersecretstore -A -o jsonpath='{.items[*].apiVersion}'` shows only `external-secrets.io/v1`; `kubectl get externalsecret -A` shows `SecretSynced`/`Ready=True` for all objects; the resulting Kubernetes Secret values are unchanged from before the migration.
      - Exit criteria: zero `external-secrets.io/v1beta1` objects remain in the cluster; every ExternalSecret is synced under `v1`.
   3. Complete the External Secrets Operator upgrade.
      - Goal: move the operator itself off the bridge version onto the module's real default.
      - Action: remove `external_secrets_chart_version = "0.16.2"` from the module call (or set it explicitly to `"2.8.0"`). Apply.
      - Verify: the operator pod is running the new chart's image; `kubectl get externalsecret -A` still shows `SecretSynced`/`Ready=True` for everything.
      - Exit criteria: operator on 2.8.0+ (v1-only line), all secrets still syncing. This stage is independent of Stage 4 and may run before, after, or in parallel with it, but both must complete before Stage 5.
   4. Migrate Linkerd (skip entirely if `linkerd.enabled = false`).
      - Goal: move the mesh off the unsupported stable-2.14 line onto the edge 2025.10.7 line supported on EKS 1.34, before the control plane moves.
      - Precondition: `linkerd check` and `linkerd check --proxy` pass clean against the current (old) install.
      - Action: remove the `linkerd` override block added in Stage 1 (or set it explicitly to the module defaults: edge repo, `2025.10.7` for all three chart versions). Apply. The module's `helm_release` dependency chain (`linkerd-crds` -> `linkerd-control-plane` -> `linkerd-viz`) installs/upgrades those three in that order within this single apply; do not attempt to stage CRDs/control-plane/viz across separate applies pointed at different repositories, the module shares one `chart_repository` across all three.
      - Verify: `linkerd check` and `linkerd check --proxy` pass against the new control plane. Existing meshed workloads' sidecars are still the OLD proxy version at this point (they only pick up the new proxy on their next pod restart) — this is expected and safe for a bounded version-skew window, not a stalled migration.
      - Follow-up (workload-level, outside this module): restart meshed workloads gradually, namespace by namespace or deployment by deployment rather than a single cluster-wide rollout, so each batch re-injects the new proxy version. Check traffic/error metrics after each batch before restarting the next.
      - Exit criteria: `linkerd check --proxy` reports every meshed pod on the new proxy version; traffic metrics healthy across all batches.
   5. Upgrade the EKS control plane to 1.34.
      - Precondition: Stage 3 and Stage 4 (if applicable) both met their exit criteria; all tooling from Stage 1 still healthy.
      - Action: set `cluster_version = "1.34"` (or remove the pin entirely, 1.34 is the module default). Apply.
      - Verify: `aws eks describe-cluster --name <cluster> --query cluster.version` returns `1.34`; `kubectl get nodes -o wide` shows nodes on a `1.34.x` kubelet version; `aws eks describe-addon` reports coredns/vpc-cni/kube-proxy/EBS/S3/ADOT as `ACTIVE`/healthy; all tooling verified in earlier stages is still healthy post-upgrade.
      - Exit criteria: cluster and all node groups report 1.34; all addons `ACTIVE`; no `CrashLoopBackOff` across kube-system or tooling namespaces. Upgrade complete.
 - from version >= 2.30.0, the AWS Load Balancer Controller's IAM identity is wired before its pods start. **No configuration change is required; expect the controller to roll once on the first apply.**
   - The problem this fixes: on a fresh install the controller could start before its IAM policy attachment (or, in `pod_identity_association` mode, before its Pod Identity association) existed. The controller receives credentials only at pod start - IRSA binds the annotated service account into the projected token at pod creation, Pod Identity injects the credential environment variables at admission - so a pod that started too early never recovered. The symptom was an Ingress stuck reporting `AccessDenied` on calls such as `elasticloadbalancing:DescribeLoadBalancers` while the policy was visibly attached to the role, cleared only by restarting the controller pods.
   - What changes: the role, the policy attachment and the Pod Identity association are now all created before the Helm release; the association no longer depends on the release; a short wait absorbs IAM/STS eventual consistency; and the identity is stamped onto the controller pod template so a later identity change rolls the deployment instead of leaving stale credentials in a running pod.
   - On upgrade: the added pod annotation changes the pod template, so the controller deployment rolls once. This is brief and self-healing, and it also clears any controller currently stuck on bad credentials. No resource is replaced and no input is removed.
   - New provider requirement: the submodule now declares `hashicorp/time ~> 0.9` for the propagation wait. Run `terraform init -upgrade` to refresh your lock file. The provider needs no configuration.
   - The wait defaults to 15 seconds on a fresh install and does not recur on applies that leave the identity unchanged. To opt out entirely:
     ```terraform
     alb_load_balancer_controller = {
       iam = {
         propagation_delay = "0s"
       }
     }
     ```

 - from version >= 2.28.0, the linkerd-crds chart installs the Gateway API CRDs by default, and the dasmeta chart pins used across `examples/` are refreshed.
   - `linkerd.configs_crds.installGatewayAPI` now defaults to `true`. The upstream linkerd-crds chart ships it as `false`, so on an existing cluster this apply **creates the Gateway API CRDs** (`httproutes` and `grpcroutes`, plus `tlsroutes`/`tcproutes` depending on the chart's `enable*Routes` values, all under `gateway.networking.k8s.io`).
   - Action is required only if something else in the cluster already owns those CRDs - an Istio or Gateway API controller install, or a separate `gateway-api` chart. Two components managing the same CRDs will fight over them. In that case set the value off explicitly:
     ```terraform
     linkerd = {
       configs_crds = {
         installGatewayAPI = false
       }
     }
     ```
   - No action is needed where Linkerd is the only Gateway API consumer, or where `linkerd.enabled = false`.
   - `examples/` now pin `dasmeta/base` `0.3.32`, and the `namespaces-and-docker-auth` submodule defaults to chart `0.1.3`. Both chart releases default their generated External Secrets resources to `external-secrets.io/v1`; see the chart release notes for the operator requirement and the per-release override.

   For configuring a cluster end to end -- assessment, upgrade order, region/timezone-specific disruption
   windows, workload and third-party chart configuration, and the disruption risk of each step -- see
   `docs/eks-stability-guide.md`.
 - from <2.30.0 to >=2.30.0 version, Karpenter gets a stability baseline. **Behaviour changes on upgrade with no configuration change; read this before applying to production.** No state migration is required.
   - Why: production 502/504 bursts occurred when spot nodes were reclaimed while the Karpenter controller was unavailable, so interruption warnings went unprocessed and nodes were never drained. A fleet-wide review tied ~35 incidents to a small set of causes, several of which were defects in this module.
   - Controller resources: requests move from `100m`/`128Mi` to `250m`/`512Mi`, the memory limit from `256Mi` to `1Gi`, and **the cpu limit is removed entirely**. The old `200m`/`256Mi` limits were diagnosed as causing cpu throttling and OOMKills during scale-up. The cpu limit is dropped rather than raised on purpose: throttling this controller during a scale-up or spot-interruption storm is the failure being prevented. Override with `karpenter.controller_resources` if you need a cpu limit back.
   - Controller priority moves from the priority-class submodule's highest class (`high`, 1,000,000) to `system-cluster-critical` (2,000,000,000), the upstream chart default. The previous value demoted Karpenter below every genuinely cluster-critical component, so under node pressure the component responsible for adding capacity was itself a preemption candidate. The controller pod is recreated by this change.
   - **AMI selection changes shape, and this is the one to plan for.** The default node class previously derived its AMI from an arbitrary running instance (`aws_instances...ids[0]`), which meant an unrelated apply could change the fleet's target image and mark every node drifted at once - the "two separate waves of change" noted in the 2.21.0 entry below. It now uses a declarative `alias` (`al2023@latest` by default, family derived from `node_groups_default.ami_type`). If the alias resolves to a different image than your nodes currently run, you get **one paced node roll**, limited by the disruption budget and suppressed during the new protected window. To avoid any roll at upgrade time, pin `karpenter.resource_configs_defaults.default.nodeClass.amiAlias` to the AMI version your nodes already use, then move the pin deliberately later.
     - Be clear about what `@latest` means AFTERWARDS: node replacement becomes **continuous and unattended**, not something tied to a terraform run. Karpenter resolves the alias itself and re-checks AMI data on its own interval (chart default `amiRefreshInterval: 1m`), so a new AWS AMI release starts a paced roll within about a minute, with no apply involved. That is the intended behaviour -- it is how nodes receive OS and kernel patches without anyone remembering to act -- and it is safe because drift is voluntary disruption, so the budgets and windows apply. If your change control requires a human to schedule node replacement, pin the version instead and put a recurring task in place to move the pin, otherwise nodes stop receiving patches.
   - Voluntary consolidation is now suppressed 06:00-18:00 UTC Monday to Friday by default, blocking `Drifted` and `Underutilized` while still allowing empty nodes to be removed. **Karpenter evaluates these schedules in UTC only - it has no timezone support - so this default is off by an hour across European daylight saving and is wrong outright for other regions.** The window is an ordinary entry in `karpenter.resource_configs_defaults.default.disruption.budgets`; remove it there to restore always-on consolidation. These budgets never delay spot interruption handling.
   - Consolidation policy moves from `WhenEmptyOrUnderutilized` to `Balanced`, and `consolidateAfter` from `3m` to `15m`. Expect less node churn and therefore somewhat higher spend; that is the intended trade.
   - **Instance selection changes shape, and this will change which instance types you get.** Requirements widen
     from cpu<9 / memory<32Gi to cpu 2-32 / memory 2-128Gi, which deepens the spot candidate pool and lowers
     interruption frequency. At the same time the burstable `t` family is now EXCLUDED via
     `instance-category In [c, m, r]`, and the generation floor moves from >2 to >4. Karpenter picks the
     cheapest instance satisfying the constraints, and without a category constraint that was very often a
     `t3.2xlarge`: burstable instances throttle to a fraction of their advertised vCPU under sustained load,
     which surfaces as latency that looks like an application fault, and they sit in the most contended spot
     pools so they are reclaimed more often. Expect a modest unit-price increase per node in exchange for
     predictable CPU and fewer interruptions. To keep burstable instances, add `"t"` back to the
     `instance-category` values via `karpenter.resource_configs_defaults.default.requirements`.
   - Check your CPU-versus-memory reservation balance before accepting the defaults. If nodes consistently run
     out of CPU while memory sits idle, constrain to `["c"]` (1:2 memory-per-core) rather than the default
     c/m/r set; if the reverse, `["r"]` (1:8). Section 14 of `scripts/eks-assess.sh` reports this per node.
   - `karpenter.resource_configs_defaults.default.terminationGracePeriod`, **unset by default**. It bounds how long a node may drain before remaining pods are removed. It is deliberately NOT enabled by default: setting it does more than bound a drain already underway, it makes a node ELIGIBLE for drift even when it hosts pods with blocking PodDisruptionBudgets or the `karpenter.sh/do-not-disrupt` annotation, and force-deletes those pods when it elapses. That converts both protections from a guarantee into a delay. A workload marked always-up stays up, and its node keeps an older AMI until a human moves it -- assessment section D4 lists such nodes and names what is holding them.
   - **Protected on-demand capacity is now a preset.** `resource_configs_defaults` gains a third key,
     `on-demand`, alongside `default` and `gpu`, and the module creates a matching `on-demand` EC2NodeClass.
     A pool referencing it inherits the on-demand requirement, an instance filter that admits burstable
     with a memory floor above the 2GiB shapes, the `dedicated=on-demand` taint, weight 50, `WhenEmpty`
     consolidation and the standard capacity ceiling -- so declaring the pool is three lines rather than fifty,
     and every field stays overridable. Nothing is created unless a pool references it.
   - Protected on-demand capacity for ingress, monitoring, singleton and stateful workloads is configured with a standard node pool in `karpenter.resource_configs.nodePools` -- an on-demand capacity-type requirement plus a taint -- not a bespoke input. Standard pools already express this and more (labels, multiple taints, a custom node class), and a pool that declares its own `budgets` is excluded from the module's disruption windows, which is what such a pool wants. See `examples/eks-with-karpenter-recommended`.
   - Karpenter charts move `1.9.0` -> `1.14.1` and `karpenter-nodes` `0.1.0` -> `0.1.2`. The CRD chart is upgraded before the main chart. If you are coming from a much older release you may still need the `kubectl patch` commands in the 2.20.0 entry below. `ec2:DescribeInstanceStatus` is granted to the controller role, which Karpenter 1.12+ requires for its interruption health checks; without it that code path fails silently with AccessDenied. It is granted through a SEPARATE managed policy attached via `iam_role_policies`, not through `iam_policy_statements`. AWS caps a managed policy at 6144 characters and the upstream controller document already measures 5966 of those for a 30-character cluster name, in which the cluster name appears 16 times -- so a name 11 characters longer exhausts the remaining headroom on its own, with or without anything we add. Going over does not degrade gracefully: the policy fails to create, the controller has no permissions at all, and karpenter launches nothing, which surfaces as unrelated workloads hanging with nowhere to schedule. A new IAM policy is created per cluster; no action is required on upgrade. Note 1.9 is the LTS line, so this moves off LTS deliberately, in exchange for the interruption health checks and `Balanced` consolidation this incident needs.
   - **Two things deliberately did NOT change**, both for the same reason - they would bypass the pacing this release adds:
     - `expireAfter` stays `Never`. Node expiry is not gated by disruption budgets, so any finite value would replace nodes unpaced and outside the protected window, and switching an existing fleet to a finite value would expire every older node at once. AMI patching is handled by budget-paced drift via the alias instead.
     - Capacity buffers (new in Karpenter 1.14) are not adopted. They add another CRD on top of a five-minor-version upgrade whose whole purpose is reducing risk. Revisit once this baseline is proven.
   - **If you previously set `budgets = [{ nodes = "0" }]` as a mitigation, remove it when adopting the windows.**
     A budget of `nodes: "0"` with no `schedule`/`duration` is always active, so it does not reduce churn -- it
     stops ALL voluntary disruption permanently. Observed on a production cluster: four of five node pools carried
     it, and with `expireAfter: Never` alongside it nothing ever replaced a node voluntarily. Nodes had reached
     33-102 days old and were still running the previous kubelet minor version after the control plane had moved
     on, because AMI drift remediation is voluntary disruption and was therefore blocked too. The disruption
     windows in this release are the supported way to express the same intent: blocked during your traffic hours,
     permitted outside them. Note the module CONCATENATES window budgets with whatever budgets you already set,
     so an existing always-on `nodes: "0"` keeps winning (budgets resolve most-restrictive-wins) and must be
     removed for the windows to have any effect.
   - **The managed node groups are now tainted `CriticalAddonsOnly=true:NoSchedule` by default, and their
     instance type is no longer burstable.** Both are node group changes, so both cause a ROLLING NODE
     REPLACEMENT of the managed group on the apply that introduces them. Do it in a maintenance window, and
     do both in the same apply so the group is replaced once rather than twice.
     - Why the taint: these nodes exist to host the karpenter controller, coredns and the CSI controllers.
       Without the taint, application pods schedule onto them and compete with the controller that
       provisions their capacity -- on a 2-node group that is how the controller ends up starved. This is
       the setting most often forgotten in production setups, which is why it is now a default rather than
       a documented recommendation.
     - What tolerates it and therefore stays: the karpenter controller, the EKS coredns addon, and the EBS
       CSI controller, all of which tolerate `CriticalAddonsOnly` out of the box. Everything else --
       ingress controllers, cert-manager, external-dns, keda, service mesh -- moves onto
       karpenter-provisioned capacity. That is the intent, not a side effect.
     - `NoSchedule` does not evict anything already running, so application pods currently on system nodes
       stay until they are next rescheduled and then migrate. The change is gradual.
     - **It is applied only when karpenter is enabled.** With karpenter off there is nowhere else for
       workloads to run, so tainting the only node groups would leave the cluster unable to schedule
       anything. Any node group that declares its own `taints` is left exactly as written.
     - Opt out with `node_groups_system_taint = { enabled = false }`, which is the right choice for
       development or test clusters where the isolation is not worth the extra capacity.
   - **Destroys now hold two controllers alive briefly** -- the load balancer controller for 30 seconds, karpenter for 60. The load balancer controller and the
     karpenter controller own AWS resources terraform did not create and cannot see -- load balancers and
     their ENIs, and EC2 instances. On a destroy terraform removes the controller while it is still
     cleaning those up, orphaning them; the orphaned ENIs then hold the node security group and the run
     fails several resources later on a security group that is not the cause. A `time_sleep` with
     `destroy_duration` widens the window. It is a mitigation, not a guarantee: delete Ingress and
     `Service type=LoadBalancer` objects and the node pools, confirm the load balancers and node claims
     are gone, and only then destroy. See "Destroying a cluster" in `docs/eks-stability-guide.md`.
     Applies add nothing; the wait is destroy-only.
   - **Known issue, not introduced by this release: a first apply can fail with `Unauthorized`.** The
     kubernetes, kubectl and helm providers authenticate with a token from `aws_eks_cluster_auth`. That
     token is minted once, is valid for exactly 15 minutes, and terraform cannot refresh it during an
     apply. Creating a cluster takes about 8 minutes and the managed node group another 2, so a first
     apply can reach its first kubernetes resource with little of that budget left; any apply that runs
     longer than 15 minutes past the token being minted loses it outright.
     - It presents as `Unauthorized`, or "the server has asked for the client to provide credentials",
       attributed to whichever resource happened to be scheduled next -- a namespace, a priority class,
       the aws-auth config map, a helm release. Those resources are not at fault; they share one expired
       credential. This is why it reads as a random first-run failure rather than an auth problem.
     - **Nothing is broken and no cleanup is needed. Run `terraform apply` again.** Everything created so
       far is in state, the cluster now exists, and the second apply mints a fresh token and finishes the
       remaining resources well inside the window.
     - To avoid the failure entirely on a first creation, build the cluster first and then the rest:
       `terraform apply -target=module.<name>.module.eks-cluster` followed by a plain `terraform apply`.
     - The permanent fix is the `exec` credential plugin, which mints a token per API request and cannot
       age out. It is not adopted here because it would make the AWS CLI a hard requirement on every
       machine and CI runner that runs terraform. Consumers who already have the CLI everywhere can opt in
       by configuring their own providers with `exec`; the `cluster_token` output stays available for
       those who do not.
   - **`kyverno.enabled` now defaults to `false`.** It was on by default only to carry the temporary
     `bitnami-to-bitnamilegacy` image rewrite, and most clusters have since migrated those references
     directly. Keeping it costs more than it gives: kyverno registers admission webhooks with
     `failurePolicy: Fail`, so the API calls they match are REJECTED whenever no healthy backend exists --
     not skipped. Its admission controller runs a single replica by default, which makes a cluster-wide veto
     depend on one pod surviving every spot reclaim, consolidation and node group upgrade. The rejections
     typically land on pod creation, so the workload that cannot start looks like the fault while the cause
     is several layers away. The same property makes it awkward to remove: the pods go, the webhooks stay
     registered, and the cleanup is rejected by itself, which presents as a `helm delete` or
     `terraform destroy` that never finishes.
     - **Before upgrading**, run `scripts/eks-assess.sh` and read section E8. It lists every running image
       still pointing at the retired `bitnami` repository. Fix each one in the workload's OWN image config
       -- a values override or a chart upgrade to `bitnamilegacy` -- rather than relying on the mutating
       policy. Doing it in the image reference means a pod no longer needs an admission webhook to be
       healthy in order to get a working image.
     - If E8 is empty, nothing needs doing: the policy has no work left and this default simply removes it.
     - Set `kyverno = { enabled = true }` to keep it, which is the right choice where the cluster genuinely
       uses policy enforcement. Give the admission controller 2+ replicas if you do -- assessment section B3
       reports every `Fail`-policy webhook alongside how many ready backends it currently has.
     - Disabling it uninstalls the release. Delete its webhook configurations first if the uninstall hangs.
   - The system node group instance type changes from `t3.large` to `t3.medium`. Same family, one size down:
     these nodes carry a small steady load -- one karpenter replica, one coredns, a CSI controller and the
     DaemonSets -- and `t3.large` was simply larger than that needs. Burstable is appropriate here precisely
     because the load is low and steady, which is the opposite of the sustained-high profile that makes
     burstable a poor choice for application nodes.
     - Sizing rule: measured karpenter controller CPU scales at roughly 3m per cluster node across a real
       fleet (45m at 7 nodes, 115m at 26, 350m at 112). `t3.medium` sustains 400m before credits are
       consumed and the other system pods take ~250m, so the default holds to roughly 50 cluster nodes.
       Beyond that, or on any sign of credit exhaustion, move to a non-burstable type:
       `node_groups_default = { instance_types = ["c6a.large", "c6i.large"] }`.
     - `t3.small` is NOT a valid choice at any cluster size. The VPC CNI allows only 11 pods on it, and the
       DaemonSets alone take about 5; and its ~1.5 GiB allocatable cannot hold the karpenter memory limit
       alongside coredns, the CSI controller and the DaemonSets.
   - Recommended monitoring, because these defaults reduce the chance of the failure but do not make it observable:
     - **CloudWatch `ApproximateAgeOfOldestMessage` on the Karpenter interruption SQS queue.** This is the single
       best leading indicator and it has an unambiguous threshold: a spot interruption notice gives 120 seconds,
       so any sustained age above that means a drain WILL be missed. In one production incident this reached 179s
       while the controller was OOMKilling, and nodes were reclaimed before draining began. Alert above ~60s.
     - Karpenter controller restart count and `OOMKilled` terminations. With the corrected resources these should
       be flat; any restarts at all mean the memory limit needs raising for that cluster's size.
     - Pending pods by reason, NodeClaim lifecycle duration, and node registration time.
   - Known limitation of the default disruption window: it protects 06:00-18:00 UTC, which ends at 20:00 in central
     European summer time. A recorded incident saw voluntary `Underutilized` eviction at 19:17 UTC (21:17 CEST),
     outside that window. If your traffic runs later, extend the window entry in `karpenter.resource_configs_defaults.default.disruption.budgets` accordingly; the default
     is deliberately not stretched to cover every setup, because a wider window means less consolidation and higher spend.
   - `karpenter.configs.replicas` stays at 2 by default and should stay there. A single replica has no failover during
     any controller restart. A production cluster running a single replica with the old limits had the controller
     OOMKilling every ~6 minutes; the interruption queue went unconsumed and nodes were reclaimed undrained.
   - Rollback: pin back to `2.29.x`. No state migration is performed in either direction, but rolling back reinstates the controller limits that caused the original OOMKills.
   - Recommended order: apply to dev or stage first, confirm the Karpenter deployment shows `250m`/`512Mi` requests with no cpu limit and `system-cluster-critical` priority, confirm `kubectl get nodepool -o yaml` shows the expected `disruption.budgets` entries, then watch one AMI roll complete before promoting to production.

 - from <2.28.0 to >=2.28.0 version, External Secrets moves off IAM users and static access keys onto EKS Pod Identity with IAM role chaining. **This is a two-repository change: the EKS module and every `external-secret-store` call must both be upgraded, in that order.** Read this whole entry before starting.
   - What changes: the controller now runs with an EKS Pod Identity association instead of reading credentials from a Kubernetes Secret. It holds no Secrets Manager access itself; it may only `sts:AssumeRole` the per-store roles (`external-secrets-store-*`) created by the `external-secret-store` module, and each of those is scoped to its own `secret:<store-name>*` prefix. The IAM user, its access keys and the `<store>-awssm-secret` Kubernetes Secret are destroyed by this upgrade, which is the intent of the change. The `eks-pod-identity-agent` addon is now installed by default, since a Pod Identity association delivers nothing without it.
   - The Helm release moves from the `terraform-module/release/helm` wrapper to a plain `helm_release`. The module carries a `moved` block for this, so the release is re-pointed in state rather than destroyed and recreated. Do not `terraform state rm` anything to "clean up" the old address; that is what causes an uninstall.

   **Step 1 - upgrade the EKS module.** Bump the module version and apply. The controller role, its `sts:AssumeRole` grant on `external-secrets-store-*`, the Pod Identity association and the agent addon are all created here. Stores still authenticate with their old static keys at this point and keep working, so this step is safe on its own.

   **Step 2 - upgrade every `external-secret-store` call** to `dasmeta/modules/aws//modules/external-secret-store` >= 2.20.0 and wire it to the EKS module's output. `controller_role_arn` is now required; `store_role_name_prefix` must match on both sides or the controller's wildcard `sts:AssumeRole` grant will not cover the store's role:
     ```hcl
     module "secret_store" {
       source  = "dasmeta/modules/aws//modules/external-secret-store"
       version = ">= 2.20.0"

       name                         = "app/prod"
       namespace                    = "prod"
       external_secrets_api_version = "external-secrets.io/v1"

       controller_role_arn    = module.eks.external_secrets.controller_role_arn
       store_role_name_prefix = module.eks.external_secrets.store_role_name_prefix

       depends_on = [module.eks]
     }
     ```
     Removed inputs: `create_user`, `aws_access_key_id`, `aws_access_secret`, `aws_role_arn` and `controller`. Applying this destroys the store's IAM user, access key and `<store>-awssm-secret` Secret, and rewrites the `SecretStore` to use `spec.provider.aws.role`. The `SecretStore` object keeps its address, so it is updated in place rather than recreated.

   **Step 3 - confirm the controller picked up its new identity.** EKS Pod Identity delivers credentials through environment variables (`AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`) injected into a pod **at admission time**, when the pod is created. Pods already running before the association existed never receive them, their AWS SDK falls back to the node instance role, and every store assume-role call fails with `AccessDenied`. Neither the association nor a Helm values change restarts those pods on its own, so the module stamps the controller's role ARN onto all three pod templates as an annotation; creating or changing the identity therefore rolls the deployments and the replacement pods get the credentials injected. If sync is still failing right after the apply, restart them by hand:
     ```sh
     kubectl rollout restart deploy -n kube-system external-secrets external-secrets-webhook external-secrets-cert-controller
     kubectl rollout status  deploy -n kube-system external-secrets --timeout=180s
     ```

   **Validation - run this after Step 2/3 and treat it as the exit criteria.** Existing Kubernetes Secrets keep their last synced values when sync breaks, so a broken store looks healthy from the workload side; the checks below force the question rather than relying on pods looking fine:
     ```sh
     # 1. Every store and secret reports ready. Any False/SecretSyncedError here is a failure.
     kubectl get clustersecretstore,secretstore -A
     kubectl get externalsecret -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,REASON:.status.conditions[0].reason

     # 2. No assume-role or permission errors in the controller.
     kubectl logs -n kube-system deploy/external-secrets --tail=200 | grep -iE 'denied|assume|forbidden|error' || echo "clean"

     # 3. The static-credential path is really gone (expect NotFound for each store).
     kubectl get secret -A | grep awssm-secret || echo "no static key secrets remain - expected"

     # 4. Prove a live re-sync actually works rather than trusting cached values: force one
     #    ExternalSecret to refetch and confirm it goes Ready again.
     kubectl annotate externalsecret <name> -n <ns> force-sync="$(date +%s)" --overwrite
     kubectl get externalsecret <name> -n <ns> -w   # expect SecretSynced, Ready=True

     # 5. End-to-end: change a value in Secrets Manager and confirm it lands in the Secret.
     kubectl get secret <target-secret> -n <ns> -o jsonpath='{.data.<KEY>}' | base64 -d
     ```
     Step 4 is the one that matters most: a store whose credentials are broken keeps serving the previously synced Secret indefinitely, so only a forced refetch distinguishes "working" from "stale".
   - If it still fails, check in this order: the `eks-pod-identity-agent` pods are running (`kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent`); `store_role_name_prefix` matches on both the EKS module and every `external-secret-store` call; the store role's `secret:<name>*` scope actually covers the secret being read (a store named `app/prod` cannot read `app/production-extra` only by luck of prefix, but it also cannot read `other/prod`); and the controller pods were actually recreated after the association appeared (`kubectl get pod -n kube-system -l app.kubernetes.io/name=external-secrets -o jsonpath='{.items[*].spec.containers[*].env[?(@.name=="AWS_CONTAINER_CREDENTIALS_FULL_URI")].name}'` should print the variable name, not empty).

## How to run
```hcl
data "aws_availability_zones" "available" {}

locals {
   cluster_endpoint_public_access = true
   cluster_enabled_log_types = ["audit"]
 vpc = {
   create = {
     name = "dev"
     availability_zones = data.aws_availability_zones.available.names
     private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
     public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
     cidr               = "172.16.0.0/16"
     public_subnet_tags = {
   "kubernetes.io/cluster/dev" = "shared"
   "kubernetes.io/role/elb"    = "1"
 }
 private_subnet_tags = {
   "kubernetes.io/cluster/dev"       = "shared"
   "kubernetes.io/role/internal-elb" = "1"
 }
   }
 }
  cluster_name = "your-cluster-name-goes-here"
 fluent_bit_name = "fluent-bit"
 log_group_name  = "fluent-bit-cloudwatch-env"
}

#(Basic usage with example of using already created VPC)
data "aws_availability_zones" "available" {}

locals {
   cluster_endpoint_public_access = true
   cluster_enabled_log_types = ["audit"]

 vpc = {
   link = {
     id = "vpc-1234"
     private_subnet_ids = ["subnet-1", "subnet-2"]
   }
 }
  cluster_name = "your-cluster-name-goes-here"
 fluent_bit_name = "fluent-bit"
 log_group_name  = "fluent-bit-cloudwatch-env"
}

# Minimum

module "cluster_min" {
 source  = "dasmeta/eks/aws"
 version = "0.1.1"

 cluster_name        = local.cluster_name
 users               = local.users

 vpc = {
   link = {
     id = "vpc-1234"
     private_subnet_ids = ["subnet-1", "subnet-2"]
   }
 }

}

# Max @TODO: the max param passing setup needs to be checked/fixed

module "cluster_max" {
 source  = "dasmeta/eks/aws"
 version = "0.1.1"

 ### VPC
 vpc = {
   create = {
     name = "dev"
    availability_zones = data.aws_availability_zones.available.names
    private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
    public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
    cidr               = "172.16.0.0/16"
    public_subnet_tags = {
  "kubernetes.io/cluster/dev" = "shared"
  "kubernetes.io/role/elb"    = "1"
 }
 private_subnet_tags = {
   "kubernetes.io/cluster/dev"       = "shared"
   "kubernetes.io/role/internal-elb" = "1"
 }
   }
 }

 cluster_enabled_log_types = local.cluster_enabled_log_types
 cluster_endpoint_public_access = local.cluster_endpoint_public_access

 ### EKS
 cluster_name          = local.cluster_name
 manage_aws_auth       = true

 # IAM users username and group. By default value is ["system:masters"]
 user = [
         {
           username = "devops1"
           group    = ["system:masters"]
         },
         {
           username = "devops2"
           group    = ["system:kube-scheduler"]
         },
         {
           username = "devops3"
         }
 ]

 # You can create node use node_group when you create node in specific subnet zone.(Note. This Case Ec2 Instance havn't specific name).
 # Other case you can use worker_group variable.

 node_groups = {
   example =  {
     name  = "nodegroup"
     name-prefix     = "nodegroup"
     additional_tags = {
         "Name"      = "node"
         "ExtraTag"  = "ExtraTag"
     }

     instance_type   = "t3.xlarge"
     max_size    = 1
     disk_size       = 50
     create_launch_template = false
     subnet = ["subnet_id"]
   }
}

node_groups_default = {
    disk_size      = 50
    instance_types = ["t3.medium"]
  }

worker_groups = {
  default = {
    name              = "nodes"
    instance_type     = "t3.xlarge"
    asg_max_size      = 3
    root_volume_size  = 50
  }
}

 workers_group_defaults = {
   launch_template_use_name_prefix = true
   launch_template_name            = "default"
   root_volume_type                = "gp3"
   root_volume_size                = 50
 }

 ### FLUENT-BIT
 fluent_bit_name = local.fluent_bit_name
 log_group_name  = local.log_group_name

 # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
 ### METRICS-SERVER
 # enable_metrics_server = false
 metrics_server_name     = "metrics-server"
}
```

## karpenter enabled
### NOTES:
###  - enabling karpenter automatically disables cluster auto-scaler, starting from 2.30.0 version karpenter is enabled by default
###  - if vpc have been created externally(not inside this module) then you may need to set the following tags on private subnets `karpenter.sh/discovery=<cluster-name>`
###  - then enabling karpenter on existing old cluster there is possibility to see cycle-dependency error, to overcome this you need at first to apply main eks module change (`terraform apply --target "module.<eks-module-name>.module.eks-cluster"`) and then rest of cluster-autoloader destroy and karpenter install ones
###  - when destroying cluster which have karpenter enabled there is possibility of failure on karpenter resource removal, you need to run destruction one more time to get it complete
###  - in order to be able to use spot instances you may need to create AWSServiceRoleForEC2Spot IAM role on aws account(TODO: check and create this role on account module automatically), here is the doc: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/service-linked-roles-spot-instance-requests.html , otherwise karpenter created `nodeclaim` kubernetes resource will show AuthFailure.ServiceLinkedRoleCreationNotPermitted error
###  - karpenter is designed to keep nodes as cheep as possible to that by default it can dynamically disrupt/collocate nodes, even on-demand ones. So in order to control the process in specific cases use following options: setting `karpenter.sh/do-not-disrupt: "true"` for pod (or this can be set also on node) prevents karpenter to disrupt the node where pod runs(be aware to manually drain such nodes when you do eks version upgrades), also pods PDB(PodDisruptionBudget) option can be used as karpenter respects this, the node-pools disruption params also can be used to create more advanced logics(my default `disruption = { consolidationPolicy="WhenEmptyOrUnderutilized", consolidateAfter="3m", budgets={nodes : "10%"}}`)

```terraform
module "eks" {
 source  = "dasmeta/eks/aws"
 version = "3.x.x"
 .....
 karpenter = {
  enabled = true
  # Optional: defaults are replicas=2 and priorityClassName="high".
  # Set only if you want to override defaults explicitly.
  # configs = {
  #   replicas          = 2
  #   priorityClassName = "high"
  # }
  resource_configs_defaults = { # this is optional param, look into karpenter submodule to get available defaults
    limits = {
      cpu = 11 # the default is 10 and we can add limit restrictions on memory also
    }
  }
  resource_configs = {
    nodePools = {
      general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
    }
  }
 }
 .....
}
```
**/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_deepmerge"></a> [deepmerge](#requirement\_deepmerge) | ~> 1.1 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_utils"></a> [utils](#requirement\_utils) | 2.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_adot"></a> [adot](#module\_adot) | ./modules/adot | n/a |
| <a name="module_alb-ingress-controller"></a> [alb-ingress-controller](#module\_alb-ingress-controller) | ./modules/aws-load-balancer-controller | n/a |
| <a name="module_api-gw-controller"></a> [api-gw-controller](#module\_api-gw-controller) | ./modules/api-gw | n/a |
| <a name="module_autoscaler"></a> [autoscaler](#module\_autoscaler) | ./modules/autoscaler | n/a |
| <a name="module_cert-manager"></a> [cert-manager](#module\_cert-manager) | ./modules/cert-manager | n/a |
| <a name="module_cloudwatch-metrics"></a> [cloudwatch-metrics](#module\_cloudwatch-metrics) | ./modules/cloudwatch-metrics | n/a |
| <a name="module_cw_alerts"></a> [cw\_alerts](#module\_cw\_alerts) | dasmeta/monitoring/aws//modules/alerts | 1.3.5 |
| <a name="module_ebs-csi"></a> [ebs-csi](#module\_ebs-csi) | ./modules/ebs-csi | n/a |
| <a name="module_efs-csi-driver"></a> [efs-csi-driver](#module\_efs-csi-driver) | ./modules/efs-csi | n/a |
| <a name="module_eks-cluster"></a> [eks-cluster](#module\_eks-cluster) | ./modules/eks | n/a |
| <a name="module_eks-core-components"></a> [eks-core-components](#module\_eks-core-components) | dasmeta/empty/null | 1.2.2 |
| <a name="module_eks-core-components-and-alb"></a> [eks-core-components-and-alb](#module\_eks-core-components-and-alb) | dasmeta/empty/null | 1.2.2 |
| <a name="module_event_exporter"></a> [event\_exporter](#module\_event\_exporter) | ./modules/event-exporter | n/a |
| <a name="module_external-dns"></a> [external-dns](#module\_external-dns) | ./modules/external-dns | n/a |
| <a name="module_external-secrets"></a> [external-secrets](#module\_external-secrets) | ./modules/external-secrets | n/a |
| <a name="module_flagger"></a> [flagger](#module\_flagger) | ./modules/flagger | n/a |
| <a name="module_fluent-bit"></a> [fluent-bit](#module\_fluent-bit) | ./modules/fluent-bit | n/a |
| <a name="module_istio"></a> [istio](#module\_istio) | dasmeta/shared/any//modules/istio | 1.7.9 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | ./modules/karpenter | n/a |
| <a name="module_keda"></a> [keda](#module\_keda) | ./modules/keda | n/a |
| <a name="module_kyverno"></a> [kyverno](#module\_kyverno) | dasmeta/shared/any//modules/kyverno | 1.5.0 |
| <a name="module_linkerd"></a> [linkerd](#module\_linkerd) | ./modules/linkerd | n/a |
| <a name="module_metrics-server"></a> [metrics-server](#module\_metrics-server) | ./modules/metrics-server | n/a |
| <a name="module_namespaces_and_docker_auth"></a> [namespaces\_and\_docker\_auth](#module\_namespaces\_and\_docker\_auth) | ./modules/namespaces-and-docker-auth | n/a |
| <a name="module_nginx-ingress-controller"></a> [nginx-ingress-controller](#module\_nginx-ingress-controller) | ./modules/nginx-ingress-controller/ | n/a |
| <a name="module_node-problem-detector"></a> [node-problem-detector](#module\_node-problem-detector) | ./modules/node-problem-detector | n/a |
| <a name="module_node_local_dns"></a> [node\_local\_dns](#module\_node\_local\_dns) | ./modules/node-local-dns | n/a |
| <a name="module_olm"></a> [olm](#module\_olm) | ./modules/olm | n/a |
| <a name="module_portainer"></a> [portainer](#module\_portainer) | ./modules/portainer | n/a |
| <a name="module_priority_class"></a> [priority\_class](#module\_priority\_class) | ./modules/priority-class/ | n/a |
| <a name="module_s3-csi"></a> [s3-csi](#module\_s3-csi) | ./modules/s3-csi | n/a |
| <a name="module_sso-rbac"></a> [sso-rbac](#module\_sso-rbac) | ./modules/sso-rbac | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | dasmeta/vpc/aws | 1.0.1 |
| <a name="module_weave-scope"></a> [weave-scope](#module\_weave-scope) | ./modules/weave-scope | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.kube-state-metrics](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.nvidia_gpu_driver](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.meta-system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | `null` | no |
| <a name="input_additional_priority_classes"></a> [additional\_priority\_classes](#input\_additional\_priority\_classes) | Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high'(1000000), 'medium'(500000) and 'low'(250000) . You can also provide a custom list of Priority Classes if needed. | <pre>list(object({<br/>    name  = string<br/>    value = string # number in string form<br/>  }))</pre> | `[]` | no |
| <a name="input_adot_config"></a> [adot\_config](#input\_adot\_config) | accept\_namespace\_regex defines the list of namespaces from which metrics will be exported, and additional\_metrics defines additional metrics to export. | <pre>object({<br/>    accept_namespace_regex = optional(string, "(default|kube-system)")<br/>    additional_metrics     = optional(list(string), [])<br/>    log_group_name         = optional(string, "adot")<br/>    log_retention          = optional(number, 14)<br/>    helm_values            = optional(any, null)<br/>    logging_enable         = optional(bool, false)<br/>    resources = optional(object({<br/>      limit = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      requests = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      }), {<br/>      limit = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>      }<br/>      requests = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>      }<br/>    })<br/>  })</pre> | <pre>{<br/>  "accept_namespace_regex": "(default|kube-system)",<br/>  "additional_metrics": [],<br/>  "helm_values": null,<br/>  "log_group_name": "adot",<br/>  "log_retention": 14,<br/>  "logging_enable": false,<br/>  "resources": {<br/>    "limit": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    },<br/>    "requests": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_adot_version"></a> [adot\_version](#input\_adot\_version) | The version of the AWS Distro for OpenTelemetry addon to use. If not passed it will get compatible version based on cluster\_version | `string` | `null` | no |
| <a name="input_alarms"></a> [alarms](#input\_alarms) | Creates cloudwatch alarms  on ContainerInsights `cluster_failed_node_count` metric. If one of adot/cloudwatch metrics\_exporters is not enabled then we have to disable alarms as specified metric do not exist and creation may fail. You need set sns topic name if you enable alarms. For customize alarms threshold use custom\_values | <pre>object({<br/>    enabled       = optional(bool, false) # we need to have cloudwatch metrics based alarms disabled by default, as we disabled adot/cloudwatch metric exporters by default.<br/>    sns_topic     = optional(string, "")<br/>    custom_values = optional(any, {})<br/>  })</pre> | `{}` | no |
| <a name="input_alb_load_balancer_controller"></a> [alb\_load\_balancer\_controller](#input\_alb\_load\_balancer\_controller) | Aws alb ingress/load-balancer controller configs. | <pre>object({<br/>    enabled            = optional(bool, true)  # Whether alb ingress/load-balancer controller enabled, note that alb load balancer will be created also when nginx_ingress_controller_config.enabled=true as nginx loadbalancer service needs it<br/>    enable_waf_for_alb = optional(bool, false) # Enables WAF and WAF V2 addons for ALB<br/>    chart = optional(object({<br/>      version    = optional(string, "3.3.0")                            # Chart version to install<br/>      repository = optional(string, "https://aws.github.io/eks-charts") # Chart repository URL, ignored when name is a direct packaged-chart URL<br/>      name       = optional(string, "aws-load-balancer-controller")     # Chart name or a direct packaged-chart URL ending with .tgz<br/>    }), {})<br/>    image = optional(object({<br/>      repository = optional(string, null) # Optional controller image repository override; when null, the chart default image is used<br/>      tag        = optional(string, null) # Optional controller image tag override; when null, the chart default tag is used<br/>    }), {})<br/>    iam = optional(object({<br/>      policy_name           = optional(string, null)                              # Optional IAM policy name override<br/>      policy_description    = optional(string, null)                              # Optional IAM policy description override<br/>      role_name             = optional(string, null)                              # Optional IAM role name override<br/>      attachment_method     = optional(string, "service_account_role_annotation") # IAM role attachment mode: service_account_role_annotation or pod_identity_association; set null to manage the association externally<br/>      use_descriptive_names = optional(bool, false)                               # When true, generate descriptive names instead of legacy cluster-based defaults<br/>      propagation_delay     = optional(string, "15s")                             # How long to wait after the role/policy/association are created before installing the chart, so the first controller pod does not start against not-yet-effective IAM. Set "0s" to skip.<br/>    }), {})<br/>    configs = optional(any, {}) # Allows to pass additional helm chart configs<br/>  })</pre> | `{}` | no |
| <a name="input_api_gateway_resources"></a> [api\_gateway\_resources](#input\_api\_gateway\_resources) | Nested map containing API, Stage, and VPC Link resources | <pre>list(object({<br/>    namespace = string<br/>    api = object({<br/>      name         = string<br/>      protocolType = string<br/>    })<br/>    stages = optional(list(object({<br/>      name        = string<br/>      namespace   = string<br/>      apiRef_name = string<br/>      stageName   = string<br/>      autoDeploy  = bool<br/>      description = string<br/>    })))<br/>    vpc_links = optional(list(object({<br/>      name      = string<br/>      namespace = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_api_gw_deploy_region"></a> [api\_gw\_deploy\_region](#input\_api\_gw\_deploy\_region) | Region in which API gatewat will be configured | `string` | `""` | no |
| <a name="input_autoscaler_image_patch"></a> [autoscaler\_image\_patch](#input\_autoscaler\_image\_patch) | The patch number of autoscaler image | `number` | `3` | no |
| <a name="input_autoscaler_limits"></a> [autoscaler\_limits](#input\_autoscaler\_limits) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_autoscaler_requests"></a> [autoscaler\_requests](#input\_autoscaler\_requests) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | Weather enable cluster autoscaler for EKS, in case if karpenter enabled this config will be ignored and the cluster autoscaler will be considered as disabled | `bool` | `true` | no |
| <a name="input_bindings"></a> [bindings](#input\_bindings) | Variable which describes group and role binding | <pre>list(object({<br/>    group     = string<br/>    namespace = string<br/>    roles     = list(string)<br/><br/>  }))</pre> | `[]` | no |
| <a name="input_cert_manager"></a> [cert\_manager](#input\_cert\_manager) | Cert-manager configuration: resources (ClusterIssuers and Certificates), configs (extra Helm values), namespace, atomic. Supports DNS01 and HTTP01 challenge solvers. | <pre>object({<br/>    # enabled       = optional(bool, false)      # Reserved: will replace create_cert_manager when migrated, check above TODO for this<br/>    # chart_version = optional(string, "1.20.0") # Reserved: will replace cert_manager_chart_version when migrated, check above TODO for this<br/>    namespace = optional(string, "cert-manager") # Namespace where cert-manager is installed<br/>    atomic    = optional(bool, true)             # Whether to auto rollback if helm install fails<br/>    configs = optional(object({                  # default configuration (Helm values) passed to the cert-manager controller chart<br/>      crds = optional(object({<br/>        enabled = optional(bool, true) # Enable CRD installation<br/>      }), {})<br/>    }), {})<br/>    extra_configs = optional(any, {}) # Extra configuration (Helm values) passed to the cert-manager controller chart<br/>    resources = optional(object({     # Configuration for cert-manager resources (ClusterIssuers and Certificates)<br/>      # Map of DNS01 secret data keyed by "${issuer.name}/${secret_ref.name}" (e.g. "letsencrypt-prod/cloudflare-api"). Pass sensitive token/API data here so for_each is not sensitive.<br/>      dns01_secret_data = optional(map(map(string)), {})<br/>      cluster_issuers = optional(list(object({<br/>        name                    = optional(string, "letsencrypt-prod")                               # Name of the ClusterIssuer resource<br/>        email                   = optional(string, "support@dasmeta.com")                            # Required - email for Let's Encrypt account registration<br/>        server                  = optional(string, "https://acme-v02.api.letsencrypt.org/directory") # ACME server URL<br/>        private_key_secret_name = optional(string, null)                                             # Optional: custom secret name for private key, defaults to cluster_issuer.name<br/>        # DNS01 challenge solver. For Route53 in the same AWS account we create the IAM role for the cert-manager controller automatically (see iam_role below).<br/>        # For other DNS providers (e.g. Cloudflare) or Route53 in another account: use secret_refs + dns01_secret_data to create API/token secrets here, or create them separately and reference in configs.<br/>        dns01 = optional(object({<br/>          enabled = optional(bool, false) # Enable DNS01 challenge solver<br/>          configs = optional(any, {})     # DNS01 solver configuration (e.g., route53 configs, or secretRef for Cloudflare/other providers)<br/>          # Optional: create Kubernetes secrets for the solver. List only names here; pass sensitive data via resources.dns01_secret_data so for_each is not sensitive. Created secret name = "${cluster_issuer.name}-${ref.name}".<br/>          secret_refs = optional(list(object({<br/>            name = string # Secret name (final name in cluster will be "${cluster_issuer.name}-${name}")<br/>          })), [])<br/>          iam_role = optional(object({<br/>            enabled          = optional(bool, true)       # Enable IAM role for DNS01 (IRSA) - uses cert-manager service account from Helm chart<br/>            hosted_zone_arns = optional(list(string), []) # Optional: restrict to specific hosted zones, empty list = all zones<br/>          }), {})<br/>        }), {})<br/>        http01 = optional(object({<br/>          enabled = optional(bool, false) # Enable HTTP01 challenge solver<br/>          gateway_http_route = optional(object({<br/>            parent_refs = optional(list(object({<br/>              name      = string                                        # Gateway name<br/>              namespace = optional(string, "istio-system")              # Gateway namespace<br/>              kind      = optional(string, "Gateway")                   # Gateway kind<br/>              group     = optional(string, "gateway.networking.k8s.io") # Gateway API group<br/>            })), [])<br/>          }), null) # Gateway API HTTP01 configuration<br/>          ingress = optional(object({<br/>            class = optional(string, "nginx") # Ingress class for HTTP01<br/>          }), null)                           # Traditional Ingress HTTP01 configuration<br/>        }), {})<br/>      })), [])<br/>      certificates = optional(list(object({<br/>        name        = string                      # Certificate resource name<br/>        namespace   = optional(string, "default") # Namespace for the certificate<br/>        secret_name = optional(string, null)      # Optional: secret name for the issued cert; default is certificate name<br/>        issuer_ref = object({<br/>          name  = string                              # ClusterIssuer name to use<br/>          kind  = optional(string, "ClusterIssuer")   # Issuer kind<br/>          group = optional(string, "cert-manager.io") # Issuer API group<br/>        })<br/>        dns_names    = optional(list(string), []) # DNS names for the certificate<br/>        common_name  = optional(string, null)     # Common name for the certificate<br/>        duration     = optional(string, null)     # Certificate duration (e.g., "2160h" for 90 days)<br/>        renew_before = optional(string, null)     # Renew before expiration (e.g., "360h" for 15 days)<br/>        usages       = optional(list(string), []) # Certificate usages (e.g., ["server auth", "client auth"])<br/>        configs      = optional(any, {})          # Extra configs to merge into the Certificate spec<br/>      })), [])<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_cert_manager_chart_version"></a> [cert\_manager\_chart\_version](#input\_cert\_manager\_chart\_version) | The cert-manager helm chart version. | `string` | `"1.20.0"` | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | Cluster addon configurations to enable. | `any` | `{}` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html) | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | n/a | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Creating eks cluster name. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Allows to set/change kubernetes cluster version, kubernetes version needs to be updated at leas once a year. Please check here for available versions https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html | `string` | `"1.34"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create cluster and other resources or not | `bool` | `true` | no |
| <a name="input_create_cert_manager"></a> [create\_cert\_manager](#input\_create\_cert\_manager) | If enabled it always gets deployed to the cert-manager namespace. | `bool` | `false` | no |
| <a name="input_default_addons"></a> [default\_addons](#input\_default\_addons) | Allows to set/override default eks addons(like coredns, kube-proxy, vpc-cni and eks-pod-identity-agent) configurations. Ww have them here to have this core components be managed via addons instead of default managed component. For coredns you can pass only the keys you want to override (e.g. replicaCount) and the rest will use module defaults. | <pre>object({<br/>    coredns = optional(object({<br/>      most_recent          = optional(bool, true)<br/>      configuration_values = optional(any, {}) # optional: pass only what you want to override (e.g. replicaCount = 3); defaults for replicaCount, resources, and corefile are applied when not set<br/>    }), {})<br/>    vpc-cni = optional(object({<br/>      most_recent          = optional(bool, true)<br/>      configuration_values = optional(any, {})<br/>    }), {})<br/>    kube-proxy = optional(object({<br/>      most_recent          = optional(bool, true)<br/>      configuration_values = optional(any, {})<br/>    }), {})<br/>    # Runs the agent DaemonSet that delivers credentials to pods through EKS Pod Identity<br/>    # associations. Installed by default because Pod Identity is the preferred way to grant AWS<br/>    # permissions to workloads in this module; without the agent an association is created but<br/>    # never hands out credentials.<br/>    eks-pod-identity-agent = optional(object({<br/>      most_recent          = optional(bool, true)<br/>      configuration_values = optional(any, {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_ebs_csi_storage_classes"></a> [ebs\_csi\_storage\_classes](#input\_ebs\_csi\_storage\_classes) | The eks ebs-csi StorageClasses to create/configure. We have predefined StorageClasses: ebs-gp3, ebs-gp2, ebs-io2-3k, ebs-io2-5k, ebs-io2-8k, ebs-io2-16k, ebs-io2-32k, ebs-io2-64k, ebs-st1 and ebs-sc1. This ones can be customized or extended with additional ones by using var.storage\_classes.extra\_configs | <pre>object({<br/>    defaults = optional(object({                                        # defaults to pass StorageClass<br/>      enabled                = optional(bool, true)                     # whether storage class enabled<br/>      default                = optional(bool, false)                    # whether storage class is default<br/>      storage_provisioner    = optional(string, "ebs.csi.aws.com")      # provisioner to use for storage class<br/>      volume_binding_mode    = optional(string, "WaitForFirstConsumer") # when volume binding and dynamic provisioning should occur<br/>      allow_volume_expansion = optional(bool, true)                     # whether the storage class allow volume expand<br/>      reclaim_policy         = optional(string, "Retain")               # whether to "Retain" or "Delete" pv on pvc removal<br/>      mount_options          = optional(list(string), [])               # mount options to set, for example ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]<br/>      parameters = optional(object({<br/>        fsType    = optional(string, "ext4") # the filesystem of the volume<br/>        encrypted = optional(string, "true") # whether to have storage encrypted<br/>        kmsKeyId  = optional(string, null)   # the custom kms key to pass to encrypt storage when encrypted=true, by default aws managed key will be used<br/>      }), {})<br/>    }), {})<br/>    extra_configs = optional(any, {}) # the map of {class-name}=>{class-configs} to customize predefined ones or create additional StorageClasses, the {class-configs} object has same field as var.storage_classes.defaults<br/>  })</pre> | `{}` | no |
| <a name="input_ebs_csi_version"></a> [ebs\_csi\_version](#input\_ebs\_csi\_version) | EBS CSI driver addon version, by default it will pick right version for this driver based on cluster\_version | `string` | `null` | no |
| <a name="input_efs_id"></a> [efs\_id](#input\_efs\_id) | EFS filesystem id in AWS | `string` | `null` | no |
| <a name="input_efs_storage_classes"></a> [efs\_storage\_classes](#input\_efs\_storage\_classes) | Additional storage class configurations: by default, 2 storage classes are created - efs-sc and efs-sc-root which has 0 uid. One can add another storage classes besides these 2. | <pre>list(object({<br/>    name : string<br/>    provisioning_mode : optional(string, "efs-ap")<br/>    file_system_id : string<br/>    directory_perms : optional(string, "755")<br/>    base_path : optional(string, "/")<br/>    uid : optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_enable_api_gw_controller"></a> [enable\_api\_gw\_controller](#input\_enable\_api\_gw\_controller) | Weather enable API-GW controller or not | `bool` | `false` | no |
| <a name="input_enable_autoscaling_group_metrics"></a> [enable\_autoscaling\_group\_metrics](#input\_enable\_autoscaling\_group\_metrics) | Whether to enable autoscaling group metrics. | `bool` | `false` | no |
| <a name="input_enable_ebs_driver"></a> [enable\_ebs\_driver](#input\_enable\_ebs\_driver) | Weather enable EBS-CSI driver or not | `bool` | `true` | no |
| <a name="input_enable_efs_driver"></a> [enable\_efs\_driver](#input\_enable\_efs\_driver) | Weather install EFS driver or not in EKS | `bool` | `false` | no |
| <a name="input_enable_external_secrets"></a> [enable\_external\_secrets](#input\_enable\_external\_secrets) | Whether to enable external-secrets operator | `bool` | `true` | no |
| <a name="input_enable_kube_state_metrics"></a> [enable\_kube\_state\_metrics](#input\_enable\_kube\_state\_metrics) | Enable kube-state-metrics | `bool` | `false` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | METRICS-SERVER | `bool` | `false` | no |
| <a name="input_enable_node_problem_detector"></a> [enable\_node\_problem\_detector](#input\_enable\_node\_problem\_detector) | n/a | `bool` | `true` | no |
| <a name="input_enable_olm"></a> [enable\_olm](#input\_enable\_olm) | To install OLM controller (experimental). | `bool` | `false` | no |
| <a name="input_enable_portainer"></a> [enable\_portainer](#input\_enable\_portainer) | Enable Portainer provisioning or not | `bool` | `false` | no |
| <a name="input_enable_sso_rbac"></a> [enable\_sso\_rbac](#input\_enable\_sso\_rbac) | Enable SSO RBAC integration or not | `bool` | `false` | no |
| <a name="input_event_exporter"></a> [event\_exporter](#input\_event\_exporter) | Allows to create/configure event\_exporter in eks cluster. The configs option is object to pass corresponding to preferred helm values.yaml, for more details check: https://artifacthub.io/packages/helm/bitnami/kubernetes-event-exporter?modal=values | <pre>object({<br/>    enabled = optional(bool, false)<br/>    configs = optional(any, {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_external_dns"></a> [external\_dns](#input\_external\_dns) | Allows to install external-dns helm chart and related roles, which allows to automatically create R53 records based on ingress/service domain/host configs | <pre>object({<br/>    enabled = optional(bool, false)<br/>    configs = optional(any, {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_external_secrets"></a> [external\_secrets](#input\_external\_secrets) | External Secrets Operator configuration. The controller authenticates to AWS through EKS Pod Identity (default) or IRSA and holds no Secrets Manager access itself; it may only assume the per-store roles created by the external-secret-store module (role chaining), so no IAM users or static access keys are involved. | <pre>object({<br/>    enabled   = optional(bool, true)            # whether to install the operator at all<br/>    namespace = optional(string, "kube-system") # namespace the controller is installed into<br/>    chart = optional(object({<br/>      name       = optional(string, "external-secrets")                   # chart name, or a full https .tgz URL for a direct/private archive<br/>      repository = optional(string, "https://charts.external-secrets.io") # helm repo URL; ignored when name is a .tgz URL<br/>      version    = optional(string, "2.8.0")                              # chart version; 2.8.0 ships the external-secrets.io/v1 API<br/>    }), {})<br/>    image = optional(object({<br/>      registry   = optional(string, null) # registry host to prepend, e.g. a private mirror; unset keeps the chart default<br/>      repository = optional(string, null) # image repository path without the registry host; unset keeps the chart default<br/>      tag        = optional(string, null) # image tag; unset keeps the chart default<br/>    }), {})<br/>    iam = optional(object({<br/>      role_name              = optional(string, null)                       # override for the controller's base IAM role name; defaults to external-secrets-<cluster>-<region><br/>      attachment_method      = optional(string, "pod_identity_association") # how the controller SA gets its role: pod_identity_association or service_account_role_annotation (IRSA)<br/>      store_role_name_prefix = optional(string, "external-secrets-store-")  # prefix of the per-store roles the controller may assume; must match the external-secret-store module<br/>    }), {})<br/>    service_account_name = optional(string, "external-secrets") # service account the controller runs as<br/>    values               = optional(any, {})                    # helm values map for the release<br/>    extra_values         = optional(any, {})                    # extra helm values merged last, highest precedence<br/>  })</pre> | `{}` | no |
| <a name="input_external_secrets_chart_version"></a> [external\_secrets\_chart\_version](#input\_external\_secrets\_chart\_version) | Deprecated: use `external_secrets.chart.version`. Kept for backward compatibility (the staged upgrade runbook pins the 0.16.2 bridge release through this variable); when set it takes precedence. Defaults to null so the grouped variable applies. | `string` | `null` | no |
| <a name="input_external_secrets_namespace"></a> [external\_secrets\_namespace](#input\_external\_secrets\_namespace) | Deprecated: use `external_secrets.namespace`. Kept for backward compatibility; when set it takes precedence. Defaults to null so the grouped variable applies. | `string` | `null` | no |
| <a name="input_flagger"></a> [flagger](#input\_flagger) | Allows to create/deploy flagger operator to have custom rollout strategies like canary/blue-green and also it allows to create custom flagger metric templates | <pre>object({<br/>    enabled                    = optional(bool, false)<br/>    namespace                  = optional(string, "ingress-nginx") # The flagger operator helm being installed on same namespace as mesh/ingress provider so this field need to be set based on which ingress/mesh we are going to use, more info in https://artifacthub.io/packages/helm/flagger/flagger<br/>    configs                    = optional(any, {})                 # Available options can be found in https://artifacthub.io/packages/helm/flagger/flagger<br/>    metrics_and_alerts_configs = optional(any, {})                 # Available options can be found in https://github.com/dasmeta/helm/tree/flagger-metrics-and-alerts-0.1.0/charts/flagger-metrics-and-alerts<br/>    enable_loadtester          = optional(bool, false)             # Whether to install flagger loadtester helm<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_fluent_bit_configs"></a> [fluent\_bit\_configs](#input\_fluent\_bit\_configs) | Fluent Bit configs | <pre>object({<br/>    enabled               = optional(string, false) # before default was `true`, we disable fluentbit by default as we are now using separate grafana stack setup module as k8s metric/log/trace collection tools<br/>    fluent_bit_name       = optional(string, "")<br/>    log_group_name        = optional(string, "")<br/>    system_log_group_name = optional(string, "")<br/>    log_retention_days    = optional(number, 90)<br/>    values_yaml           = optional(string, "")<br/>    s3_permission         = optional(bool, false)<br/>    configs = optional(object({<br/>      inputs                     = optional(string, "")<br/>      filters                    = optional(string, "")<br/>      outputs                    = optional(string, "")<br/>      cloudwatch_outputs_enabled = optional(bool, true)<br/>    }), {})<br/>    drop_namespaces        = optional(list(string), [])<br/>    log_filters            = optional(list(string), [])<br/>    additional_log_filters = optional(list(string), [])<br/>    kube_namespaces        = optional(list(string), [])<br/>    image_pull_secrets     = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "additional_log_filters": [<br/>    "ELB-HealthChecker",<br/>    "Amazon-Route53-Health-Check-Service"<br/>  ],<br/>  "configs": {<br/>    "cloudwatch_outputs_enabled": true,<br/>    "filters": "",<br/>    "inputs": "",<br/>    "outputs": ""<br/>  },<br/>  "drop_namespaces": [<br/>    "kube-system",<br/>    "opentelemetry-operator-system",<br/>    "adot",<br/>    "cert-manager",<br/>    "opentelemetry.*",<br/>    "meta.*"<br/>  ],<br/>  "enabled": false,<br/>  "fluent_bit_name": "",<br/>  "image_pull_secrets": [],<br/>  "kube_namespaces": [<br/>    "kube.*",<br/>    "meta.*",<br/>    "adot.*",<br/>    "devops.*",<br/>    "cert-manager.*",<br/>    "git.*",<br/>    "opentelemetry.*",<br/>    "stakater.*",<br/>    "renovate.*"<br/>  ],<br/>  "log_filters": [<br/>    "kube-probe",<br/>    "health",<br/>    "prometheus",<br/>    "liveness"<br/>  ],<br/>  "log_group_name": "",<br/>  "log_retention_days": 90,<br/>  "s3_permission": false,<br/>  "system_log_group_name": "",<br/>  "values_yaml": ""<br/>}</pre> | no |
| <a name="input_istio"></a> [istio](#input\_istio) | Allows to create/configure Istio with Gateway API in eks cluster. NOTE: IAM role is typically NOT needed - AWS Load Balancer Controller (which has its own IAM role) handles LoadBalancer creation for all LoadBalancer services, including those created by istio-gateway Helm chart and Gateway API Gateways. | <pre>object({<br/>    enabled = optional(bool, false)<br/>    configs = optional(any, {}) # Istio configuration, see terraform-any-shared/modules/istio for available options<br/>  })</pre> | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Allows to create/deploy/configure karpenter operator and its resources to have custom node auto-scaling.<br/><br/>Defaults include replicas=2, priorityClassName=system-cluster-critical, Balanced consolidation with a 15m<br/>settle time, declarative AMI selection via alias, and a 06:00-18:00 UTC Mon-Fri window during which<br/>voluntary consolidation is suppressed. Disruption windows are evaluated in UTC only and should be<br/>overridden for setups outside central Europe. | <pre>object({<br/>    enabled                   = optional(bool, true)<br/>    configs                   = optional(any, {})                               # karpenter chart configs, merged on top of module defaults (replicas=2, priorityClassName=system-cluster-critical). Lowering replicas to 1 leaves the controller with no failover during any restart; see modules/karpenter/variables.tf. Options: https://github.com/aws/karpenter-provider-aws/blob/v1.14.1/charts/karpenter/values.yaml<br/>    resource_configs          = optional(any, { nodePools = { general = {} } }) # karpenter resources creation configs, available options can be fount here: https://github.com/dasmeta/helm/tree/karpenter-resources-0.1.0/charts/karpenter-resources<br/>    resource_configs_defaults = optional(any, {})                               # the default used for karpenter node pool creation, the available values to override/set can be found in karpenter submodule corresponding variable modules/karpenter/values.tf<br/>    controller_resources      = optional(any, null)                             # resources for the karpenter controller container; defaults to requests 250m/512Mi with a 1Gi memory limit and deliberately no cpu limit, see modules/karpenter/variables.tf<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_keda"></a> [keda](#input\_keda) | Allows to create/deploy/configure keda | <pre>object({<br/>    enabled          = optional(bool, true)<br/>    name             = optional(string, "keda")   # keda chart name,<br/>    namespace        = optional(string, "keda")   # keda chart namespace<br/>    create_namespace = optional(bool, true)       # create keda chart<br/>    keda_version     = optional(string, "2.20.0") # chart version<br/>    attach_policies = optional(object({<br/>      sqs = bool<br/>    }), { sqs = false })<br/>    keda_trigger_auth_additional = optional(any, null)<br/>  })</pre> | <pre>{<br/>  "create_namespace": true,<br/>  "enabled": true,<br/>  "keda_version": "2.20.0",<br/>  "name": "keda",<br/>  "namespace": "keda"<br/>}</pre> | no |
| <a name="input_kube_state_metrics_chart_version"></a> [kube\_state\_metrics\_chart\_version](#input\_kube\_state\_metrics\_chart\_version) | The kube-state-metrics chart version | `string` | `"7.8.1"` | no |
| <a name="input_kyverno"></a> [kyverno](#input\_kyverno) | Allows to enable/install the kyverno k8s policies management tool/operator. Disabled by default since 2.30.0: it carries a cluster-wide admission webhook with failurePolicy=Fail, and the predefined "bitnami-to-bitnamilegacy" policy it shipped for was a temporary migration aid. Pin the registry in each workload image instead -- eks-assess.sh section E8 lists any that still need it. | <pre>object({<br/>    # Default OFF since 2.30.0. kyverno registers admission webhooks with failurePolicy=Fail, which means the<br/>    # API calls they match are REJECTED whenever no healthy backend exists rather than being skipped -- so an<br/>    # admission controller with too few replicas is a cluster-wide veto held by a single pod. It was enabled<br/>    # by default only to carry the temporary `bitnami-to-bitnamilegacy` image rewrite, which is a workaround,<br/>    # not a permanent policy engine requirement. Pin the registry in the workload's own image config instead;<br/>    # assessment section E8 lists any image still pointing at `bitnami`. Enable this only where the cluster<br/>    # genuinely uses policy enforcement, and give the admission controller 2+ replicas when you do.<br/>    enabled         = optional(bool, false)<br/>    policies        = optional(list(string), ["bitnami-to-bitnamilegacy"]) # Predefined kyverno rules to apply/enable. supported rule are "bitnami-to-bitnamilegacy"<br/>    custom_policies = optional(any, [])                                    # Custom kyverno rules to apply. The custom policies are list of objects. check for more details in terraform module "dasmeta/shared/any//modules/kyverno"<br/>    extra_configs   = optional(any, {})                                    # Configs to pass and override kyverno helm values.yaml defaults and var.default_configs if needed more fine control. for more info check https://artifacthub.io/packages/helm/kyverno/kyverno?modal=values<br/>  })</pre> | `{}` | no |
| <a name="input_linkerd"></a> [linkerd](#input\_linkerd) | Allows to create/configure linkerd in eks cluster | <pre>object({<br/>    enabled            = optional(bool, true)<br/>    chart_repository   = optional(string, "https://helm.linkerd.io/edge") # Linkerd Helm repository to use for CRDs, control plane, and viz charts<br/>    crds_chart_version = optional(string, "2025.10.7")                    # linkerd-crds chart version<br/>    chart_version      = optional(string, "2025.10.7")                    # linkerd-control-plane chart version<br/>    viz_chart_version  = optional(string, "2025.10.7")                    # linkerd-viz chart version<br/>    configs            = optional(any, {})                                # allows to override default configs of linkerd main helm chart, check underlying sub-module module for more info<br/>    configs_crds       = optional(any, {})                                # allows to override default configs of the linkerd-crds helm chart, the module defaults installGatewayAPI to true; set it to false where another component already owns the Gateway API CRDs<br/>    configs_viz        = optional(any, {})                                # allows to override default configs of linkerd viz helm chart, check underlying sub-module module for more info<br/>    crds_create        = optional(bool, true)                             # whether to have linkerd crd installed<br/>    viz_create         = optional(bool, true)                             # whether to have linkerd monitoring/dashboard tooling installed<br/>  })</pre> | <pre>{<br/>  "chart_repository": "https://helm.linkerd.io/edge",<br/>  "chart_version": "2025.10.7",<br/>  "crds_chart_version": "2025.10.7",<br/>  "enabled": true,<br/>  "viz_chart_version": "2025.10.7"<br/>}</pre> | no |
| <a name="input_manage_aws_auth"></a> [manage\_aws\_auth](#input\_manage\_aws\_auth) | n/a | `bool` | `true` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br/>    rolearn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_metrics_exporter"></a> [metrics\_exporter](#input\_metrics\_exporter) | Metrics Exporter, can use `cloudwatch` or `adot` | `string` | `"none"` | no |
| <a name="input_metrics_server_chart_version"></a> [metrics\_server\_chart\_version](#input\_metrics\_server\_chart\_version) | Metrics Server Helm chart version | `string` | `"7.4.12"` | no |
| <a name="input_metrics_server_name"></a> [metrics\_server\_name](#input\_metrics\_server\_name) | n/a | `string` | `"metrics-server"` | no |
| <a name="input_namespaces_and_docker_auth"></a> [namespaces\_and\_docker\_auth](#input\_namespaces\_and\_docker\_auth) | Allows to create application namespaces, like 'prod' or 'dev' automatically. it can also set to use docker hub credential for image pull | <pre>object({<br/>    enabled = optional(bool, false)<br/>    list    = optional(list(string), []) # list of application namespaces to create/init with cluster creation<br/>    labels  = optional(any, {})          # map of key=>value strings to attach to namespaces<br/>    dockerAuth = optional(object({       # docker hub image registry configs, this based external secrets operator(operator should be enabled). which will allow to create 'kubernetes.io/dockerconfigjson' type secrets in app(and also all other) namespaces and configure app namespaces to use this<br/>      enabled                 = optional(bool, false)<br/>      refreshTime             = optional(string, "3m")                                         # frequency to check filtered namespaces and create ExternalSecrets (and k8s secret)<br/>      refreshInterval         = optional(string, "1h")                                         # frequency to pull/refresh data from aws secret<br/>      name                    = optional(string, "docker-registry-auth")                       # the name to use when creating k8s resources<br/>      secretManagerSecretName = optional(string, "account")                                    # aws secret manager secret name where dockerhub credentials placed, we use "account" default secret<br/>      namespaceSelector       = optional(any, { matchLabels : { "docker-auth" = "enabled" } }) # namespaces selector expression, the app namespaces created here will have this selectors by default, but for other namespaces you may need to set labels manually. this can be set to empty object {} to create secrets in all namespaces<br/>      registries = optional(list(object({                                                      # docker registry configs<br/>        url         = optional(string, "https://index.docker.io/v1/")                          # docker registry server url<br/>        usernameKey = optional(string, "DOCKER_HUB_USERNAME")                                  # the aws secret manager secret key where docker registry username placed<br/>        passwordKey = optional(string, "DOCKER_HUB_PASSWORD")                                  # the aws secret manager secret key where docker registry password placed, NOTE: for dockerhub under this key should be set personal access token instead of standard ui/profile password<br/>        authKey     = optional(string)                                                         # the aws secret manager secret key where docker registry auth placed<br/>      })), [{ url = "https://index.docker.io/v1/", usernameKey = "DOCKER_HUB_USERNAME", passwordKey = "DOCKER_HUB_PASSWORD", authKey = null }])<br/>    }), { enabled = false })<br/>  })</pre> | `{}` | no |
| <a name="input_nginx_ingress_controller_config"></a> [nginx\_ingress\_controller\_config](#input\_nginx\_ingress\_controller\_config) | Nginx ingress controller configs | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    name             = optional(string, "nginx")<br/>    create_namespace = optional(bool, true)<br/>    namespace        = optional(string, "ingress-nginx")<br/>    chart_version    = optional(string, "4.15.1")<br/>    replicacount     = optional(number, 3)<br/>    metrics_enabled  = optional(bool, true)<br/>    configs          = optional(any, {}) # Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.15.1?modal=values<br/>  })</pre> | <pre>{<br/>  "chart_version": "4.15.1",<br/>  "create_namespace": true,<br/>  "enabled": false,<br/>  "metrics_enabled": true,<br/>  "name": "nginx",<br/>  "namespace": "ingress-nginx",<br/>  "replicacount": 3<br/>}</pre> | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node group definitions to create.<br/><br/>These nodes exist to host the cluster's own control components -- the karpenter controller, coredns, CSI<br/>controllers -- not application workloads. Karpenter provisions everything else, and by default this group<br/>is tainted so applications land there instead (see var.node\_groups\_system\_taint).<br/><br/>Defaults are sized for that job:<br/>  - min/desired 2, spread across availability zones. The karpenter chart requires each of its 2 replicas<br/>    on a SEPARATE node in a SEPARATE zone, and karpenter-provisioned nodes are ineligible to host it, so<br/>    fewer than 2 nodes here makes a highly available controller impossible regardless of cluster size.<br/>  - t3.medium as a cost-appropriate default for the common case. See the sizing note below; the one type<br/>    that does NOT work is t3.small.<br/>  - max 2, equal to desired. Nothing scales this group on its own -- karpenter does not manage managed<br/>    node groups and no cluster autoscaler runs alongside it -- so the node count stays at desired\_size<br/>    and a ceiling above it is only ever used by EKS to surge during a rolling replacement. Production<br/>    clusters in the fleet run max equal to desired, including at 1/1/1, with no node group upgrade<br/>    problems, so the surge is not needed in practice. The consequence to know: a rolling replacement<br/>    dips to a single node, so one karpenter replica is Pending until the new node joins. The surviving<br/>    replica keeps reconciling throughout. Raise to 3 to keep both replicas schedulable during a<br/>    replacement, at the cost of one node's headroom you otherwise never use.<br/><br/>SIZING. System nodes carry a small, steady load: one karpenter replica, one coredns, a CSI controller and<br/>the DaemonSets. Measured karpenter controller CPU across a real fleet scales at roughly 3m per cluster<br/>node (45m at 7 nodes, 115m at 26, 350m at 112). t3.medium sustains 400m before credits are consumed, and<br/>the rest of the system pods take ~250m, so the default holds comfortably to roughly 50 cluster nodes.<br/><br/>Above that, or if you observe CPU credit exhaustion on these nodes, move to a non-burstable type:<br/><br/>  node\_groups\_default = { instance\_types = ["c6a.large", "c6i.large"] }<br/><br/>Do NOT use t3.small. It fails on two hard limits regardless of load: the VPC CNI allows only 11 pods on it<br/>((3 ENIs x (4 IPs - 1)) + 2), and the DaemonSets alone take about 5 of those; and its 2 GiB leaves roughly<br/>1.5 GiB allocatable, which cannot hold the karpenter memory limit plus coredns, the CSI controller and the<br/>DaemonSets. t3.medium gives 17 pods and 4 GiB, which fits with headroom. | `any` | <pre>{<br/>  "default": {<br/>    "ami_type": "AL2023_x86_64_STANDARD",<br/>    "capacity_type": "ON_DEMAND",<br/>    "desired_size": 2,<br/>    "iam_role_additional_policies": {<br/>      "CloudWatchAgentServerPolicy": "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br/>    },<br/>    "instance_types": [<br/>      "t3.medium",<br/>      "t3a.medium"<br/>    ],<br/>    "max_size": 2,<br/>    "min_size": 2<br/>  }<br/>}</pre> | no |
| <a name="input_node_groups_default"></a> [node\_groups\_default](#input\_node\_groups\_default) | Map of EKS managed node group default configurations, applied to every entry in var.node\_groups.<br/>See var.node\_groups for the instance sizing rationale and when to move off the default type. | `any` | <pre>{<br/>  "ami_type": "AL2023_x86_64_STANDARD",<br/>  "capacity_type": "ON_DEMAND",<br/>  "disk_size": 50,<br/>  "iam_role_additional_policies": {<br/>    "CloudWatchAgentServerPolicy": "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br/>  },<br/>  "instance_types": [<br/>    "t3.medium",<br/>    "t3a.medium"<br/>  ]<br/>}</pre> | no |
| <a name="input_node_groups_system_taint"></a> [node\_groups\_system\_taint](#input\_node\_groups\_system\_taint) | Reserves the EKS managed node groups for cluster-critical components by tainting them, so application<br/>workloads are provisioned by karpenter onto dedicated capacity instead of crowding onto the small system<br/>nodes. This is the setting most often forgotten in production setups, and forgetting it is how application<br/>pods end up starving the karpenter controller on a 2-node group.<br/><br/>ONLY APPLIED WHEN KARPENTER IS ENABLED. Without karpenter there is nowhere else for workloads to run, so<br/>tainting the only node groups would leave the cluster unable to schedule anything.<br/><br/>It is also skipped for any node group that already declares its own `taints`, so an explicit choice always<br/>wins.<br/><br/>Components that tolerate this key by default and therefore stay on system nodes: the karpenter controller,<br/>the EKS coredns addon, and the EBS CSI controller. Everything else -- ingress controllers, cert-manager,<br/>external-dns, keda, service mesh -- moves to karpenter-provisioned capacity, which is the intent.<br/><br/>Set enabled = false for development or test clusters where the isolation is not worth the extra capacity,<br/>or where karpenter is enabled but you want workloads to be able to fall back onto the system group. | <pre>object({<br/>    enabled = optional(bool, true)                   # whether to taint managed node groups so only cluster-critical components run there<br/>    key     = optional(string, "CriticalAddonsOnly") # the conventional key; karpenter, coredns and the EBS CSI controller all tolerate it out of the box<br/>    value   = optional(string, "true")               # taint value<br/>    effect  = optional(string, "NO_SCHEDULE")        # NO_SCHEDULE keeps new pods off without evicting anything already running<br/>  })</pre> | `{}` | no |
| <a name="input_node_local_dns"></a> [node\_local\_dns](#input\_node\_local\_dns) | Allows to enable/install the NodeLocal DNSCache, to improves Cluster DNS performance | <pre>object({<br/>    enabled = optional(bool, false) # TODO: in case having local-dns enabled is common case consider having it enabled by default, for now only high load having setups may need to enable local-dns caching<br/>    configs = optional(any, {})<br/>  })</pre> | `{}` | no |
| <a name="input_node_security_group_additional_rules"></a> [node\_security\_group\_additional\_rules](#input\_node\_security\_group\_additional\_rules) | n/a | `any` | <pre>{<br/>  "ingress_cluster_10250": {<br/>    "description": "Metric server to node groups",<br/>    "from_port": 10250,<br/>    "protocol": "tcp",<br/>    "self": true,<br/>    "to_port": 10250,<br/>    "type": "ingress"<br/>  }<br/>}</pre> | no |
| <a name="input_nvidia_gpu_driver"></a> [nvidia\_gpu\_driver](#input\_nvidia\_gpu\_driver) | Configuration block for enabling and customizing the NVIDIA GPU driver installation. | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    namespace        = optional(string, "kube-system")<br/>    create_namespace = optional(bool, false)<br/>    configs = optional(any, {<br/>      nodeSelector = {<br/>        nodetype = "gpu"<br/>      }<br/><br/>      tolerations = [<br/>        {<br/>          effect   = "NoSchedule"<br/>          key      = "nodetype"<br/>          operator = "Equal"<br/>          value    = "gpu"<br/>        }<br/>      ]<br/><br/>      affinity = null # empty affinity<br/>    })<br/>  })</pre> | `{}` | no |
| <a name="input_portainer_config"></a> [portainer\_config](#input\_portainer\_config) | Portainer hostname and ingress config. | <pre>object({<br/>    host           = optional(string, "portainer.dasmeta.com")<br/>    enable_ingress = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_prometheus_metrics"></a> [prometheus\_metrics](#input\_prometheus\_metrics) | Prometheus Metrics | `any` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | `null` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | Variable describes which role will user have K8s | <pre>list(object({<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_s3_csi"></a> [s3\_csi](#input\_s3\_csi) | S3 CSI driver addon version, by default it will pick right version for this driver based on cluster\_version | <pre>object({<br/>    enabled       = optional(bool, false)<br/>    addon_version = optional(string, null)     # if not passed it will use latest compatible version<br/>    buckets       = optional(list(string), []) # the name of buckets to create policy to be able to mount them to containers, if not specified it uses all/*<br/>    configs = optional(object({                # allows to pass additional addon configs to override default ones<br/>      node = optional(object({<br/>        tolerateAllTaints = optional(bool, true) # Whether mountpoint for S3 CSI Driver Pods will tolerate all taints and will be scheduled in all nodes<br/>      }), {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_scale_down_unneeded_time"></a> [scale\_down\_unneeded\_time](#input\_scale\_down\_unneeded\_time) | Scale down unneeded in minutes | `number` | `2` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra tags to attach to eks cluster. | `any` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to open eks cluster api access | `list(any)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration for eks, we support both cases create new vpc(create field) and using already created one(link) | <pre>object({<br/>    # for linking using existing vpc<br/>    link = optional(object({<br/>      id                 = string<br/>      private_subnet_ids = list(string) # please have the existing vpc public/private subnets(at least 2 needed) tagged with corresponding tags(look into create case subnet tags defaults)<br/>    }), { id = null, private_subnet_ids = null })<br/>    # for creating new vpc<br/>    create = optional(object({<br/>      name                = string<br/>      availability_zones  = list(string)<br/>      cidr                = string<br/>      private_subnets     = list(string)<br/>      public_subnets      = list(string)<br/>      public_subnet_tags  = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/elb" = 1}<br/>      private_subnet_tags = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/internal-elb" = 1}<br/>    }), { name = null, availability_zones = null, cidr = null, private_subnets = null, public_subnets = null })<br/>  })</pre> | n/a | yes |
| <a name="input_weave_scope_config"></a> [weave\_scope\_config](#input\_weave\_scope\_config) | Weave scope namespace configuration variables | <pre>object({<br/>    create_namespace        = bool<br/>    namespace               = string<br/>    annotations             = map(string)<br/>    ingress_host            = string<br/>    ingress_class           = string<br/>    ingress_name            = string<br/>    service_type            = string<br/>    weave_helm_release_name = string<br/>  })</pre> | <pre>{<br/>  "annotations": {},<br/>  "create_namespace": true,<br/>  "ingress_class": "",<br/>  "ingress_host": "",<br/>  "ingress_name": "weave-ingress",<br/>  "namespace": "meta-system",<br/>  "service_type": "NodePort",<br/>  "weave_helm_release_name": "weave"<br/>}</pre> | no |
| <a name="input_weave_scope_enabled"></a> [weave\_scope\_enabled](#input\_weave\_scope\_enabled) | Weather enable Weave Scope or not | `bool` | `false` | no |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | Worker groups. | `any` | `{}` | no |
| <a name="input_workers_group_defaults"></a> [workers\_group\_defaults](#input\_workers\_group\_defaults) | Worker group defaults. | `any` | <pre>{<br/>  "launch_template_name": "default",<br/>  "launch_template_use_name_prefix": true,<br/>  "root_volume_size": 50,<br/>  "root_volume_type": "gp3"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | n/a |
| <a name="output_alb_load_balancer_controller"></a> [alb\_load\_balancer\_controller](#output\_alb\_load\_balancer\_controller) | Combined AWS load balancer controller module output object. |
| <a name="output_cert_manager_certificate_names"></a> [cert\_manager\_certificate\_names](#output\_cert\_manager\_certificate\_names) | Map of created cert-manager Certificate resource names by namespace/name |
| <a name="output_cert_manager_cluster_issuer_names"></a> [cert\_manager\_cluster\_issuer\_names](#output\_cert\_manager\_cluster\_issuer\_names) | Map of ClusterIssuer names created by cert-manager module |
| <a name="output_cluster_certificate"></a> [cluster\_certificate](#output\_cluster\_certificate) | EKS cluster certificate used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | EKS cluster host name used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | n/a |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | n/a |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | n/a |
| <a name="output_cluster_token"></a> [cluster\_token](#output\_cluster\_token) | EKS cluster token used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_eks_auth_configmap"></a> [eks\_auth\_configmap](#output\_eks\_auth\_configmap) | n/a |
| <a name="output_eks_module"></a> [eks\_module](#output\_eks\_module) | n/a |
| <a name="output_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#output\_eks\_oidc\_root\_ca\_thumbprint) | Grab eks\_oidc\_root\_ca\_thumbprint from oidc\_provider\_arn. |
| <a name="output_external_secret_deployment"></a> [external\_secret\_deployment](#output\_external\_secret\_deployment) | Deprecated: the external-secrets module now installs the chart through a plain helm\_release and no longer exposes a `deployment` object. Kept so existing references keep resolving; use `external_secrets` instead. |
| <a name="output_external_secrets"></a> [external\_secrets](#output\_external\_secrets) | External Secrets controller details. `controller_role_arn` is the base role each per-store role must trust, and is what the external-secret-store module expects as `controller_role_arn`. |
| <a name="output_map_user_data"></a> [map\_user\_data](#output\_map\_user\_data) | n/a |
| <a name="output_namespaces_and_docker_auth_helm_metadata"></a> [namespaces\_and\_docker\_auth\_helm\_metadata](#output\_namespaces\_and\_docker\_auth\_helm\_metadata) | n/a |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ## CLUSTER |
| <a name="output_region"></a> [region](#output\_region) | n/a |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | n/a |
| <a name="output_role_arns_without_path"></a> [role\_arns\_without\_path](#output\_role\_arns\_without\_path) | n/a |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The cidr block of the vpc |
| <a name="output_vpc_default_security_group_id"></a> [vpc\_default\_security\_group\_id](#output\_vpc\_default\_security\_group\_id) | The ID of default security group created for vpc |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The newly created vpc id |
| <a name="output_vpc_nat_public_ips"></a> [vpc\_nat\_public\_ips](#output\_vpc\_nat\_public\_ips) | The list of elastic public IPs for vpc |
| <a name="output_vpc_private_subnets"></a> [vpc\_private\_subnets](#output\_vpc\_private\_subnets) | The newly created vpc private subnets IDs list |
| <a name="output_vpc_public_subnets"></a> [vpc\_public\_subnets](#output\_vpc\_public\_subnets) | The newly created vpc public subnets IDs list |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
