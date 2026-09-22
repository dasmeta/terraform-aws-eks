# eks-with-karpenter-recommended

The reference Karpenter setup. Copy this when starting a new spot-backed cluster, or diff an existing cluster
against it.

**This is a Karpenter-focused reference, not a standard every cluster must match.** Nothing in it is
mandatory. Real setups differ by region, traffic shape, cost target, compliance and what the workloads
actually do, and the module is built to be configured for each of them rather than to enforce one answer.
Several values here should be reconsidered per cluster rather than copied: the disruption window is UTC and
cut for central Europe, the instance filters assume general-purpose workloads, and the on-demand pool assumes
a handful of singletons rather than anything CPU-hungry. Where a choice has a real trade-off, the comment
next to it says what you give up by changing it -- so a deliberate difference is easy to make, and an
accidental one is easy to spot.

Every option the module or chart already applies is written out but **commented**, so the full recommended
shape is visible in one place without re-declaring behaviour you already get. Anything left **uncommented** is
set deliberately and carries the reason on the line above it.

When adapting it: delete every commented block first. If the result still says what you need, you are done —
the defaults are the recommendation.

> For applying this to an EXISTING cluster rather than starting fresh, follow
> [`docs/eks-stability-guide.md`](../../docs/eks-stability-guide.md). It covers the
> assessment checks, the order to apply changes in, the disruption risk of each step, and how to pick a
> disruption window for your region. This example is the destination; that guide is the route.

## What this demonstrates

| Layer | What is shown |
| --- | --- |
| System capacity | A 2-node, 2-AZ tainted system node group, which is what Karpenter's own 2 replicas require to schedule |
| Controller | Resources, priority and replica count, with the reasoning for each |
| Node lifecycle | Declarative AMI selection, `Balanced` consolidation, disruption windows, drain ceiling |
| Protected capacity | An opt-in on-demand pool, and a workload correctly pinned to it |
| Workload safety | Replica floors, disruption budgets, spread, shutdown timing, probes and requests |
| Ingress | An ALB rather than an in-cluster controller, so there is no ingress data plane to reclaim |

Two components are enabled purely so the example is testable end to end and are **not** part of the
recommendation: `external_dns`, which creates the Route53 records for the example hostnames, and the two
`http-echo` releases. Delete both when adapting this. Real setups usually manage DNS elsewhere, and enabling
external-dns against a zone another system already writes will have the two overwrite each other.

## The five things that actually cause outages

Each of these is a failure seen in production, and each is addressed somewhere in this example.

1. **The controller runs out of memory and stops reading the interruption queue.** Spot gives a 120 second
   notice. If the controller is restarting, messages sit unread past that and the node is reclaimed with no
   drain at all. Nothing else in this file helps when that happens. See `controller_resources` in
   `1-example.tf`.
2. **A single controller replica has no failover.** Any restart — rollout, drain, OOM — is a gap in
   interruption handling. Keep `replicas = 2`, which needs **2 managed-node-group nodes in 2 availability
   zones**. Karpenter-managed nodes do not count: the chart's `karpenter.sh/nodepool DoesNotExist` affinity
   excludes them. A cluster can run many nodes across three zones and still not be able not schedule a second
   replica, because only 1 of the 8 came from a managed node group.
3. **A service with no PodDisruptionBudget can lose every replica at once.** `rollingUpdate.maxUnavailable`
   does nothing here; only a PDB gates the eviction API during a node drain.
4. **A PodDisruptionBudget that permits zero evictions is worse than none.** It blocks consolidation, blocks
   spot replacement, and makes node group upgrades fail on pod eviction — while presenting as Karpenter or
   the upgrade being stuck. Never set `minAvailable` equal to your replica floor. See the warning in
   `http-echo.yaml`.
5. **Singletons and stateful workloads on spot capacity.** A single database or monitoring pod on a
   reclaimable node is an outage waiting for a spot event. Use the protected pool, and note that the
   toleration alone is not enough — see `http-echo-critical.yaml`.

## Files

| File | Purpose |
| --- | --- |
| `0-setup.tf` | Providers and VPC lookup |
| `1-example.tf` | The module configuration, with defaults shown and commented |
| `http-echo.yaml` | A normal spot-backed application |
| `http-echo-critical.yaml` | A workload pinned to protected on-demand capacity |

## Requirements

- Base chart **0.4.0 or newer**. That release creates PodDisruptionBudgets by default and refuses to render
  one that permits zero evictions.

  > **Requires `dasmeta/base` 0.4.0 or later**, which is the version that creates a safe PodDisruptionBudget
  > by default and refuses one permitting zero evictions. It is published, so this example applies as written.
- The account must have a default VPC, since `0-setup.tf` looks one up by tag.
- Region is `eu-central-1`; change it in `0-setup.tf`.

## Disruption windows are UTC only

Karpenter has no timezone support — schedules are always interpreted in UTC. The default window protects
06:00–18:00 UTC, which ends at 20:00 central European summer time and is offset by an hour across daylight
saving. Voluntary eviction has been seen just after a window like this closes. Extend `duration`, or move
`schedule`, to match when your traffic actually stops.

Disruption windows gate **voluntary** disruption only. They never delay spot interruption handling, and they
never delay node expiry.

## Verifying a cluster against this

```sh
# can this cluster even host 2 controller replicas? count MANAGED-node-group nodes and their zones --
# karpenter-provisioned nodes are not eligible, so a large cluster can still fail this
kubectl get nodes -L topology.kubernetes.io/zone,karpenter.sh/nodepool

# controller sizing and replica count -- 256Mi or replicas 1 means exposed
kubectl -n karpenter get deploy karpenter \
  -o jsonpath='{.spec.replicas}{"  "}{.spec.template.spec.containers[0].resources}{"\n"}'

# AMI selection -- an `id:` here means node replacement can trigger without a config change
kubectl get ec2nodeclass -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.amiSelectorTerms}{"\n"}{end}'

# disruption posture -- expect Balanced, a 15m settle, and a scheduled budget
kubectl get nodepool -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.disruption}{"\n"}{end}'

# budgets that permit nothing -- these block drains and fail node group upgrades
kubectl get pdb -A -o json \
  | jq -r '.items[]|"\(.metadata.namespace)/\(.metadata.name) allowed=\(.status.disruptionsAllowed)"' \
  | grep 'allowed=0'
```

The single best leading indicator that the controller is not keeping up is the interruption queue's
`ApproximateAgeOfOldestMessage` in CloudWatch. Sustained above the 120 second spot notice means a drain
**will** be missed. Alert above roughly 60 seconds.

```sh
aws cloudwatch get-metric-statistics --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=Karpenter-<cluster-name> \
  --start-time $(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Maximum --region <region> --output table
```

A healthy cluster reports `0.0` for every datapoint: messages are consumed as fast as they arrive. Note the
metric is only published when the queue has activity, so a handful of datapoints across several days is
normal and means that many interruption or rebalance events occurred. Also check a window that actually
contains a known incident before concluding a cluster is fine — a window starting after the event only shows
the recovered state.

### One more failure shape worth checking

A budget of `nodes: "0"` with no `schedule` or `duration` is **always active**, so it does not reduce churn —
it stops every voluntary disruption permanently. Paired with `expireAfter: Never` it means nodes are never
replaced at all, so AMI patching stops too, because drift remediation is itself voluntary disruption. One
clusters have carried it on most node pools, leaving nodes many months days old still running the
previous kubelet minor version. Use a scheduled budget entry instead: blocked during traffic hours, permitted
outside them.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.http_echo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.http_echo_critical](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpcs.ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
