# EKS upgrade runbook: Kubernetes 1.34 → 1.35

For the delivery team, upgrading client clusters built on `dasmeta/eks/aws`. Follow the stages in order. Each
stage ends with a check that must pass before the next one starts.

Ticket: DMVP-10889. Module release: **3.2.0** (1.35 becomes the default `cluster_version`).

## Why and when

| Version | End of standard support | End of extended support |
|---|---|---|
| 1.34 | **2026-12-02** | 2027-12-02 |
| 1.35 | 2027-03-27 | 2028-03-27 |
| 1.36 | 2027-08-02 | 2028-08-02 |

The module does not set an EKS upgrade policy, so clusters use the AWS default `EXTENDED`. A cluster still on
1.34 after 2026-12-02 is **not** force-upgraded. It keeps running and is billed at the extended-support rate
instead. Upgrade before that date.

1.35 leaves standard support in March 2027, so plan the 1.36 upgrade soon after this one.

## What to expect

These numbers come from the live test described in [Test evidence](#test-evidence). Use them to plan the
maintenance window.

| Step | Duration | Effect on workloads |
|---|---|---|
| Control plane 1.34 → 1.35 | ~7 min | Brief API-server unavailability. The test app behind an ALB saw 2 failed requests (502) out of ~5,000. |
| Managed node group roll | ~15 min | Nodes are replaced with surge and drained within PodDisruptionBudgets. No failed requests. |
| AWS add-ons (coredns, kube-proxy, vpc-cni, EBS CSI, pod identity) | ~5 min | DaemonSet pods restart one node at a time. |
| Karpenter nodes | Later, in the disruption window | See [Karpenter nodes](#karpenter-nodes-move-later-by-design). |

Allow **about 45 minutes** for the apply, plus a re-apply if the token expires (see
[Known issues](#known-issues-and-recovery)).

No Kubernetes API is removed in 1.35, and none of the module's charts or add-on defaults needed changing.

## Prerequisites

- [ ] Cluster is on **1.34** and healthy: `aws eks describe-cluster --name <cluster> --query cluster.status` returns `ACTIVE`.
- [ ] Module is on **3.1.0** or later, and every earlier entry in the "Upgrade guide" in the module README has
  been completed. Moving from an older major version is a separate project; do not combine it with this one.
- [ ] Terraform **>= 1.8**.
- [ ] You can run `terraform apply` for this client with an AWS session that stays valid for **at least 1 hour**.
  Long applies have hit both SSO expiry and the 15-minute EKS token (see [Known issues](#known-issues-and-recovery)).
- [ ] `kubectl` access to the cluster, and the `aws` CLI with the same account.
- [ ] A maintenance window. The disruption is small, but the control plane step is not zero.

## Stage 0 — Assess (read-only)

Run the assessment against the client cluster:

```sh
aws eks update-kubeconfig --name <cluster> --region <region>
./scripts/eks-assess.sh > assess-before.txt
```

Read these sections. Fix anything marked here before going further.

| Section | Must show | If not |
|---|---|---|
| **U1** Amazon Linux 2 nodes | `none` | Move that capacity to AL2023 first. There is no AL2 AMI after 1.32, and the module now fails the plan if a managed group still declares `AL2_*` (see [AL2 guard](#the-plan-fails-with-has-no-amazon-linux-2-ami)). |
| **U1** container runtimes | `containerd://2.x` only | A `containerd 1.x` node is an old or custom image. 1.35 still runs it, but 1.36 does not, so replace it now. |
| **U1** kube-proxy mode | `iptables` | `ipvs` still works on 1.35 but is deprecated. Plan the move to nftables; it does not block this upgrade. |
| **U1** helm releases pending or failed | `none` | Recover the release first (`helm history`, `helm rollback`). A stuck release fails the apply with "another operation is in progress". |
| **U1** deprecated APIs | nothing marked "removed in 1.35" | Nothing is removed in 1.35. Anything "removed in 1.36+" is for the next upgrade. |
| **U1** EKS upgrade insights | every check `PASSING` | `aws eks describe-insight --cluster-name <cluster> --id <id>`. Insights refresh about once a day, so a fresh fix can still show as failing. |
| **E1** zero-eviction PDBs | `none` | A PDB that allows 0 evictions blocks the node group roll, and the managed node group update then fails after its timeout. Fix the PDB or scale the workload up first. |
| **D4** nodes held back from replacement | reviewed | Expected for Karpenter pools with disruption budgets. Note them; they move after the upgrade too. |

Also check by hand. The assessment cannot see these:

1. **Client chart version pins** in the module call. Any of these must be at least the version shown, or be
   removed so the module default applies:

   | Input | Minimum for 1.35 |
   |---|---|
   | `karpenter.chart_version` / Karpenter | 1.9 (module default 1.14.1) |
   | `external_secrets_chart_version` | remove the old `0.16.x` pin and use the module default 2.8.0 (supports 1.35–1.36). It needs `external-secrets.io/v1` in SecretStores and ExternalSecrets, so follow the module's External Secrets upgrade entry first. |
   | Linkerd chart versions | the edge 2025.10.x line (module default). The old `stable-2.14` pins do not support 1.35. |
   | cert-manager | 1.20 (module default) |

2. **Custom AMIs, launch templates or kubelet flags** in `node_groups` or Karpenter node classes.
   - 1.35 kubelets refuse to start on cgroup v1.
   - The `--pod-infra-container-image` flag is removed.
   - The module defaults (AL2023, no custom kubelet flags) are unaffected.

3. **Subnet tags, only for clusters on a VPC the module did not create** (`vpc.link`). Every subnet that nodes
   can land in needs the tag `kubernetes.io/cluster/<cluster-name>`. Without it, the AWS Load Balancer
   Controller leaves that zone out of the ALB, and pods there receive no traffic. This is not caused by 1.35,
   but a node roll moves pods between zones, so check it now:

   ```sh
   aws ec2 describe-subnets --subnet-ids <id1> <id2> <id3> \
     --query 'Subnets[].[SubnetId,AvailabilityZone,Tags[?Key==`kubernetes.io/cluster/<cluster-name>`]|[0].Value]' --output text
   ```

   Every subnet must show `shared` or `owned`. If one is missing, tag it, then see
   [ALB does not serve a zone](#alb-does-not-serve-a-zone) for how to make an existing ALB pick it up.

## Stage 1 — Adopt module 3.2.0, still on 1.34

The goal is to change the module version with no version bump, so that any surprise in the new release shows
up on its own.

1. Set the module version and pin the current Kubernetes version explicitly. 3.2.0 changes the default to
   1.35, so without the pin this step would also upgrade the cluster:

   ```hcl
   module "eks" {
     source  = "dasmeta/eks/aws"
     version = "3.2.0"

     cluster_version = "1.34"
     # ...
   }
   ```

2. `terraform init -upgrade`, then `terraform plan`.

**Expected plan, with Karpenter enabled:**

- `+ create` for `module.<name>.module.karpenter[0].terraform_data.wait_for[0]`. This is a new ordering gate
  that exists only in Terraform state; nothing is created in AWS.
- `~ update in-place` for `module.<name>.module.karpenter[0].helm_release.karpenter_nodes`, with values
  `(known after apply)`. Creating the gate makes Terraform read the node AMI after the apply, so the values
  show as unknown. They resolve to the same content.
- Possibly `~ update in-place` with `(known after apply)` on client modules that depend on the EKS module,
  such as `external-secret-store`. The values do not change.
- **Nothing else.** In particular, no `-/+` or `must be replaced` on `aws_eks_cluster`, `aws_eks_node_group`
  or any `aws_iam_role_policy_attachment`.

Without Karpenter, the plan shows no changes.

3. `terraform apply`. It takes about a minute.

**Check:** `terraform plan` now shows **No changes**.

## Stage 2 — Upgrade to 1.35

1. Change the pin, or remove it to use the new module default:

   ```hcl
   cluster_version = "1.35"
   ```

2. `terraform plan`. **Expected**, about `1 to add, 15 to change, 1 to destroy` depending on enabled components
   (the add and destroy are the `time_sleep` replacement):

   | Resource | Action | Why |
   |---|---|---|
   | `aws_eks_cluster.this[0]` | `~` version `"1.34" -> "1.35"` | the upgrade |
   | `aws_eks_node_group.this[0]` (each managed group) | `~` version `"1.34" -> "1.35"` | rolls the group's nodes |
   | `aws_eks_addon.*` (coredns, kube-proxy, vpc-cni, eks-pod-identity-agent, aws-ebs-csi-driver) | `~` addon_version `(known after apply)` | each add-on moves to its 1.35 version |
   | `time_sleep.this[0]` | `+/-` replace | its trigger includes `cluster_version`; it is only a wait |
   | IAM policies and roles (external-dns, external-secrets, Karpenter controller), SQS queue policy, OIDC provider, `helm_release.karpenter_nodes` | `~` values `(known after apply)` | read again after the cluster update. The values do not change |

   **Stop and investigate if you see any of these:**
   - `-/+` or `must be replaced` on `aws_eks_cluster` or `aws_eks_node_group`.
   - `must be replaced` on any `aws_iam_role_policy_attachment`. On module versions before 3.2.0 this is the
     Karpenter node role bug: see [Karpenter nodes cannot pull images](#karpenter-nodes-cannot-pull-images-during-the-upgrade-module--320).
   - `Resource precondition failed ... has no Amazon Linux 2 AMI`. See [AL2 guard](#the-plan-fails-with-has-no-amazon-linux-2-ami).

3. Refresh the AWS session so it is valid for at least another hour, then run `terraform apply`.

The apply runs in this order: control plane, then node groups, then add-ons, then Helm releases.

While it runs, you can watch from a second terminal:

```sh
watch -n 30 'aws eks describe-cluster --name <cluster> --query "cluster.[version,status]" --output text;
  aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <group> --query "nodegroup.[version,status]" --output text;
  kubectl get nodes; kubectl get pods -A | grep -vE "Running|Completed"'
```

What you will see:
- Nodes going NotReady one at a time while the group rolls, then disappearing.
- Pods briefly not running while they move.
- Extra nodes from the roll's surge, which are removed at the end.

All of this is expected.

If the apply ends with **`Kubernetes cluster unreachable: the server has asked for the client to provide credentials`**,
run `terraform apply` again. See [the 15-minute token](#the-apply-stops-with-cluster-unreachable--provide-credentials).

## Stage 3 — Verify

```sh
CLUSTER=<cluster>; REGION=<region>

# Control plane and node groups on 1.35
aws eks describe-cluster --name $CLUSTER --region $REGION --query 'cluster.[version,status]' --output text
for ng in $(aws eks list-nodegroups --cluster-name $CLUSTER --region $REGION --query 'nodegroups[]' --output text); do
  aws eks describe-nodegroup --cluster-name $CLUSTER --region $REGION --nodegroup-name $ng \
    --query 'nodegroup.[nodegroupName,version,releaseVersion,status]' --output text; done

# Add-ons ACTIVE, on 1.35 versions
for a in $(aws eks list-addons --cluster-name $CLUSTER --region $REGION --query 'addons[]' --output text); do
  aws eks describe-addon --cluster-name $CLUSTER --region $REGION --addon-name $a \
    --query 'addon.[addonName,addonVersion,status]' --output text; done

# Nodes, pods, releases
kubectl get nodes -o wide                         # managed nodes v1.35.x, AL2023, containerd 2.x
kubectl get pods -A | grep -vE 'Running|Completed' # expect nothing
helm list -A -a                                   # every release "deployed"

# Karpenter
kubectl get nodepool,ec2nodeclass,nodeclaim       # all Ready; see below for Drifted

# Client applications: their own health checks, ingresses, ExternalSecrets
kubectl get externalsecret -A                     # SecretSynced

# Terraform has converged
terraform plan                                    # No changes
```

Then run `./scripts/eks-assess.sh > assess-after.txt`. Section U1 now reports readiness for **1.36**. Keep both
files with the change record.

**Done when:**
- control plane and every managed group are on 1.35;
- add-ons are ACTIVE;
- no pods are failing;
- client health checks pass;
- `terraform plan` shows no changes.

Karpenter nodes still on 1.34 do **not** block completion. See the next section.

## Karpenter nodes move later, by design

Karpenter nodes are not replaced during the apply.

- **The `general` (spot) pool** uses the `al2023@latest` image alias. The alias moves to the 1.35 image as
  soon as the control plane is on 1.35.
- **The `on-demand` pool** is pinned to the managed node group's AMI. That pin moves to the 1.35 AMI in the
  same apply.
- **Either way**, Karpenter marks the old nodes `Drifted` and replaces them only when the pool's disruption
  budget allows. The module's default budget blocks drift replacement on weekdays from 06:00 to 18:00 UTC
  (`schedule: "0 6 * * mon-fri"`, `duration: 12h`). Replacement then happens one node at a time, within PDBs.

So after an apply during working hours, expect Karpenter nodes to stay on 1.34 until the evening. This is
supported: kubelets may run up to three minor versions behind the control plane, and the EKS "Kubelet version
skew" insight accepts it.

To confirm:

```sh
kubectl get nodeclaim -o custom-columns='NAME:.metadata.name,NODE:.status.nodeName,DRIFTED:.status.conditions[?(@.type=="Drifted")].status'
kubectl get events -A --field-selector reason=DisruptionBlocked   # "due to blocking budget" = waiting for the window
```

To move one node now, for example to prove the new image works for that client before the window, delete its
NodeClaim. Karpenter launches the replacement first and then drains the old node within PDBs:

```sh
kubectl delete nodeclaim <name>
```

Check the next morning that no Karpenter node is left on 1.34.

## Known issues and recovery

### The apply stops with `cluster unreachable` / `provide credentials`

```
Error: Kubernetes cluster unreachable: the server has asked for the client to provide credentials
```

**Cause:** the Kubernetes and Helm providers are configured with a token from `aws_eks_cluster_auth` (for
example `token = module.eks.cluster_token`). That token expires after 15 minutes, and the upgrade apply takes
longer. Every AWS change has already been made by the time the Helm step fails.

**Recovery:** run `terraform apply` again. It gets a fresh token and finishes the remaining Helm and
Kubernetes resources. This happened on both live upgrades in testing. Nothing was lost.

### The apply fails partway, and the next run says the cluster "already exists"

**Cause:** the AWS session expired while a long-running create was in progress, for example SSO credentials
in the middle of creating an EKS cluster. Terraform marks the resource **tainted** and plans to replace it.
The replacement fails on the name with `409 ResourceInUseException: Cluster already exists`.

**Recovery:** do **not** `terraform import`. The resource is already in state, so the import fails with
"Resource already managed by Terraform". Clear the taint instead:

```sh
terraform untaint 'module.<name>.module.eks-cluster[0].module.eks-cluster.aws_eks_cluster.this[0]'
terraform plan   # no "must be replaced"
terraform apply
```

First confirm in AWS that the object is healthy (`aws eks describe-cluster ... --query cluster.status` returns
`ACTIVE`). The same applies to any other tainted resource.

### Karpenter nodes cannot pull images during the upgrade (module < 3.2.0)

**Fixed in 3.2.0.** This is why Stage 1 is required: adopt 3.2.0 **before** bumping the version.

**What happened on older module versions:**
- Any `cluster_version` bump planned the Karpenter node role's three policy attachments for replacement:
  `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy` and `AmazonEC2ContainerRegistryReadOnly`.
- Terraform detached them at the start of the apply and reattached them only after the managed node groups
  had finished rolling, about 20 minutes later.
- Every Karpenter node launched in that window could not pull images (`ImagePullBackOff` on `aws-node`) and
  stayed NotReady.
- Workloads that needed those nodes stayed Pending. The add-ons showed DEGRADED.

**If you must bump the version on a module older than 3.2.0,** watch the role during the apply and put the
policies back as soon as they disappear. Attaching an already-attached policy has no effect, so Terraform's
own step later still succeeds:

```sh
ROLE=$(aws iam list-roles --query "Roles[?starts_with(RoleName,'Karpenter-<first 25 chars of cluster name>')].RoleName" --output text)
aws iam list-attached-role-policies --role-name "$ROLE"
for p in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly; do
  aws iam attach-role-policy --role-name "$ROLE" --policy-arn "arn:aws:iam::aws:policy/$p"
done
```

Set `ROLE` in the same shell that runs the loop. If it is empty, `--role-name` fails with
`expected one argument`.

Stuck nodes recover by themselves within a few minutes once the policies are back.

### The plan fails with `has no Amazon Linux 2 AMI`

```
Resource precondition failed: cluster_version 1.35 has no Amazon Linux 2 AMI, but these are still configured: node_groups.<name>=AL2_x86_64
```

This is intended. AWS publishes no AL2 EKS AMI after 1.32. Without this check, the apply would upgrade the
control plane and only then fail on the node group, leaving the cluster half upgraded.

**Fix:** move the named groups (or `node_groups_default`) to `AL2023_x86_64_STANDARD`, or to `BOTTLEROCKET_*`
or the matching ARM type, as a separate change **on the current version**. Then upgrade.

### ALB does not serve a zone

**Symptom:** after the node roll, an ingress returns 503. The target group shows targets as `unused` with
`Target.NotInUse — Target is in an Availability Zone that is not enabled for the load balancer`.

**Cause:** a subnet without the `kubernetes.io/cluster/<cluster-name>` tag is skipped by the Load Balancer
Controller (see Stage 0). The pods now run only in that zone.

**Fix:**
1. Tag the subnet.
2. Make the existing ALB pick up the new zone. Adding the tag alone is not enough: for an ALB that already
   exists, the controller keeps its current subnets, even after a restart. Name the subnets once on the
   ingress, wait for the ALB to list the new zone, then remove the annotation. The ALB keeps the zones.

```sh
kubectl -n <ns> annotate ingress <name> alb.ingress.kubernetes.io/subnets=<subnet-a>,<subnet-b>,<subnet-c> --overwrite
aws elbv2 describe-load-balancers --names <alb-name> --query 'LoadBalancers[0].AvailabilityZones[].ZoneName'
kubectl -n <ns> annotate ingress <name> alb.ingress.kubernetes.io/subnets-
```

If a Helm chart manages the ingress, remove the annotation the same way so the chart's next release does not
fight it.

### New cluster: an app started before its ExternalSecret synced

This applies to fresh installs, not upgrades.

On a brand-new cluster, the SecretStore can fail validation for a few minutes while its new IAM role becomes
usable. Apps that load the secret with `envFrom ... optional: true` start without it and do not pick it up
later.

**Fix:** once `kubectl get externalsecret -A` shows `SecretSynced`, run `kubectl rollout restart` on those
deployments.

## Rollback

**Not tested live.** Use only if 1.35 is the cause of a serious problem that cannot be fixed forward.

EKS allows an in-place upgrade to be rolled back one minor version within **7 days**:
- A cluster *created* on 1.35 cannot be rolled back.
- Add-ons are not rolled back automatically.

Terraform cannot do this on its own. It updates the cluster before the node groups, and a rollback needs the
reverse order. Use the CLI, then bring Terraform back in line:

```sh
# 0. Check eligibility
aws eks list-insights --cluster-name <cluster> --filter '{"categories":["ROLLBACK_READINESS"]}'

# 1. Managed node groups first, each one. If EKS refuses to move a group back, create a replacement group
#    on 1.34 and remove the 1.35 one instead.
aws eks update-nodegroup-version --cluster-name <cluster> --nodegroup-name <group> --kubernetes-version 1.34

# 2. Then the control plane (add --force only after reading every failing rollback insight)
aws eks update-cluster-version --name <cluster> --kubernetes-version 1.34

# 3. Bring Terraform back in line
#    set cluster_version = "1.34", then:
terraform plan     # review add-on version changes; keep a newer add-on if EKS refuses the downgrade
terraform apply
```

**Karpenter after a rollback:** the `al2023@latest` alias follows the control plane back to 1.34, and the
on-demand pin follows the managed nodes on the next apply. Karpenter nodes therefore drift back within their
disruption window, like the forward upgrade. For a fast rollback, delete the NodeClaims of the 1.35 nodes.

## Delivery checklist

Copy into the change ticket for each client cluster:

- [ ] Prerequisites met (module ≥ 3.1.0, cluster 1.34 ACTIVE, Terraform ≥ 1.8, session ≥ 1 h, window agreed)
- [ ] `eks-assess.sh` run; U1, E1 and D4 reviewed; `assess-before.txt` attached
- [ ] Chart version pins, custom AMIs, kubelet flags and subnet tags checked by hand
- [ ] Stage 1: module 3.2.0 adopted with `cluster_version = "1.34"`; plan matched the expected list; applied; plan now shows no changes
- [ ] Stage 2: plan matched the expected list (no cluster, node group or IAM attachment replacement); applied (re-applied if the token expired)
- [ ] Stage 3: control plane and managed groups on 1.35, add-ons ACTIVE, no failing pods, client checks pass, plan shows no changes; `assess-after.txt` attached
- [ ] Next day: no Karpenter node left on 1.34
- [ ] Client informed; next upgrade (1.36) noted, needed before 2027-03-27

## Test evidence

Tested on 2026-11-13 and 2026-11-18 in the DasMeta test account (eu-central-1), using
`examples/eks-with-karpenter-and-external-secret`. That example is a typical client setup: Karpenter with spot
and on-demand pools, External Secrets with an AWS Secrets Manager store, ALB ingress with external-dns, the
module's default add-ons, Linkerd and KEDA, plus an app reading a secret behind an ALB.

**Fresh install on 1.35** (module default):
- All components healthy.
- Managed and Karpenter nodes on kubelet v1.35.9, AL2023, containerd 2.3.7.
- EKS upgrade insights passing for 1.36.

**Upgrade 1.34 → 1.35,** starting from a cluster built with released module 3.1.0:
- Stage 1 (adopting the in-repo module at 1.34): empty plan. That was before the Karpenter fix, which now adds
  the `terraform_data` gate described in Stage 1.
- Control plane: 7 min.
- Node group roll: about 15 min.
- `/ping` through the ALB, once per second: **2 errors out of ~5,000**, both during the control plane step.
- This run found the Karpenter node role bug above. It was fixed before the release.

**Upgrade 1.35 → 1.36 with the fix,** to verify the IAM change:
- No node-role attachment in the plan.
- All 3 policies attached at every check during the apply.
- No `DetachRolePolicy` calls in CloudTrail.
- Attachment IDs unchanged.
- **0 errors in 1,839** `/ping` requests.
