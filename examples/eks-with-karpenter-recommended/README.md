# eks-with-karpenter-recommended

The reference Karpenter setup. Copy this when starting a new spot-backed cluster, or diff an existing cluster
against it.

Every option the module or chart already applies is written out but **commented**, so the full recommended
shape is visible in one place without re-declaring behaviour you already get. Anything left **uncommented** is
set deliberately and carries the reason on the line above it.

When adapting it: delete every commented block first. If the result still says what you need, you are done —
the defaults are the recommendation.

## What this demonstrates

| Layer | What is shown |
| --- | --- |
| System capacity | A 2-node, 2-AZ tainted system node group, which is what Karpenter's own 2 replicas require to schedule |
| Controller | Resources, priority and replica count, with the reasoning for each |
| Node lifecycle | Declarative AMI selection, `Balanced` consolidation, disruption windows, drain ceiling |
| Protected capacity | An opt-in on-demand pool, and a workload correctly pinned to it |
| Workload safety | Replica floors, disruption budgets, spread, shutdown timing, probes and requests |

## The five things that actually cause outages

Each of these is a failure seen in production, and each is addressed somewhere in this example.

1. **The controller runs out of memory and stops reading the interruption queue.** Spot gives a 120 second
   notice. If the controller is restarting, messages sit unread past that and the node is reclaimed with no
   drain at all. Nothing else in this file helps when that happens. See `controller_resources` in
   `1-example.tf`.
2. **A single controller replica has no failover.** Any restart — rollout, drain, OOM — is a gap in
   interruption handling. Keep `replicas = 2`, which needs 2 nodes in 2 availability zones.
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
- The account must have a default VPC, since `0-setup.tf` looks one up by tag.
- Region is `eu-central-1`; change it in `0-setup.tf`.

## Disruption windows are UTC only

Karpenter has no timezone support — schedules are always interpreted in UTC. The default window protects
06:00–18:00 UTC, which ends at 20:00 central European summer time and is offset by an hour across daylight
saving. A recorded incident saw voluntary eviction at 19:17 UTC, just outside it. Extend `duration`, or move
`schedule`, to match when your traffic actually stops.

Disruption windows gate **voluntary** disruption only. They never delay spot interruption handling, and they
never delay node expiry.

## Verifying a cluster against this

```sh
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
