# Karpenter Stability Guide

**Audience**: delivery and support engineers, and the AI agents working on their behalf.
**Purpose**: configure Karpenter, the `dasmeta/base` chart, and third-party charts so a spot-backed EKS
cluster stops causing service disruption.
**Scope**: one cluster at a time, in the order given. The order matters — several steps are unsafe before the
one preceding them.

Every recommendation here traces to a production incident. Where a step can cause disruption, the risk is
stated on the step rather than buried in a footnote.

---

## How to use this document

Work top to bottom. Each phase has an **entry gate** — do not start it until the gate passes. Each step
states what changes, why, what can go wrong, and how to verify.

If you are an AI agent: do not skip the assessment phase and do not batch phases together. The assessment
output determines which later steps apply, and several steps are destructive if their precondition is unmet.
Report findings and ask before applying anything in Phase 2 or later.

---

## Phase 0 — Assess (read-only, always safe)

**Entry gate**: none. Run this on any cluster, any time.

Collect all of it before changing anything. Later phases branch on these answers.

**Fastest path**: `./scripts/eks-assess.sh --queue Karpenter-<cluster> --region <region>` runs every
check below in one pass and is strictly read-only. The individual commands are kept here so you can run any
one of them on its own, and so the script is auditable rather than a black box.

```sh
# 0.1 Controller sizing, replica count, restarts
kubectl -n karpenter get deploy karpenter \
  -o jsonpath='{.spec.replicas}{"  "}{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'

# 0.2 Controller priority
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter \
  -o jsonpath='{.items[*].spec.priorityClassName}{"\n"}'

# 0.3 Karpenter version
kubectl -n karpenter get deploy karpenter -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# 0.4 AMI selection
kubectl get ec2nodeclass -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.amiSelectorTerms}{"\n"}{end}'

# 0.5 Disruption posture per node pool
kubectl get nodepool -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.disruption}{"  expireAfter="}{.spec.template.spec.expireAfter}{"\n"}{end}'

# 0.6 Controller-eligible nodes: managed node group only, and their zones
kubectl get nodes -L topology.kubernetes.io/zone,karpenter.sh/nodepool

# 0.7 Budgets that permit nothing
kubectl get pdb -A -o json \
  | jq -r '.items[]|"\(.metadata.namespace)/\(.metadata.name) allowed=\(.status.disruptionsAllowed) expected=\(.status.expectedPods)"' \
  | grep 'allowed=0'

# 0.8 Multi-replica workloads with no PDB
kubectl get deploy -A -o json | jq -r '.items[]|select(.spec.replicas>=2)|"\(.metadata.namespace)/\(.metadata.name)"' | sort

# 0.9 Stateful and singleton workloads sitting on spot capacity
kubectl get nodes -l karpenter.sh/capacity-type=spot -o name | sed 's|node/||' > /tmp/spot.txt
kubectl get pods -A -o json | jq -r '.items[]|select(.spec.nodeName!=null)|"\(.metadata.namespace)/\(.metadata.name) \(.spec.nodeName)"' \
  | grep -Ff /tmp/spot.txt | grep -E 'mysql|postgres|prometheus|grafana|redis|elastic|kafka|kube-state-metrics|ingress'

# 0.10 Is the interruption queue keeping up?
aws cloudwatch get-metric-statistics --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=Karpenter-<cluster-name> \
  --start-time $(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Maximum --region <region> --output table
```

### Reading the results

| Check | Healthy | Exposed |
| --- | --- | --- |
| 0.1 | memory limit >= `1Gi`, `replicas: 2`, no `OOMKilled` | `256Mi`, or `replicas: 1`, or any OOMKill |
| 0.2 | `system-cluster-critical` | `high` or any custom class |
| 0.3 | `1.14.x` | `1.9.x` or older |
| 0.4 | `alias: al2023@...` | `id: ami-...` — replacement can trigger with no config change |
| 0.5 | `Balanced`, a scheduled budget | `WhenEmptyOrUnderutilized` with a short `consolidateAfter`, or an always-on `nodes: "0"` |
| 0.6 | 2+ nodes with an EMPTY `NODEPOOL` column, in 2+ zones | fewer than 2 — see the trap below |
| 0.7 | no output | any row — that workload blocks node drains and node group upgrades |
| 0.8 | every entry has a PDB | entries with none lose all replicas to one drain |
| 0.9 | no output | stateful or singleton workloads on reclaimable capacity |
| 0.10 | every datapoint `0.0` | sustained above ~60s; above 120s means drains are being missed |

**The trap in 0.6**: Karpenter-managed nodes cannot host the Karpenter controller. The chart sets a
`karpenter.sh/nodepool DoesNotExist` node affinity, so only managed-node-group nodes are eligible. A cluster
with 8 nodes across 3 zones was observed unable to schedule a second replica because 7 were Karpenter-provisioned.
Count rows where the `NODEPOOL` column is **empty**, not total nodes.

**Reading 0.10**: the metric publishes only when the queue has activity, so a handful of datapoints across
several days is normal. An all-zero result means messages are consumed as fast as they arrive. Check a window
that actually contains a known incident before concluding a cluster is fine — a window starting after the
event shows only the recovered state.

---

## Phase 1 — Upgrade the module

**Entry gate**: Phase 0 complete, findings recorded and shared.

**Do this first.** Most later configuration options do not exist before this version, and hand-patching the
cluster in the meantime is actively counterproductive — see the warning below.

### 1.1 Read the upgrade guide

The `2.30.0` entry in the module header docs (`main.tf`) is the authoritative list of what changes. Read it
in full before applying. This document does not repeat it.

### 1.2 Never rely on an in-cluster hotfix

If someone previously patched controller resources directly in the cluster, **the next `terraform apply`
reverts it**. Helm owns that Deployment: a `kubectl patch` or `kubectl edit` changes the live object but not
the release manifest, so the next `helm upgrade` the module performs restores the module's values.

The wider problem is that the corrected values were applied to one cluster in June 2026 and never landed in
the module. Every other cluster therefore kept the failing defaults. Two months later a different cluster was
found still on `200m`/`256Mi`, with the controller OOMKilling roughly every six minutes during an incident.
Move the measured values into Terraform:

```hcl
karpenter = {
  controller_resources = {
    requests = { cpu = "500m", memory = "512Mi" } # your MEASURED values, not the module default
    limits   = { memory = "1Gi" }                  # no cpu limit, on purpose
  }
}
```

If the cluster is running higher values than the module default and they were measured under load, **pin
them**. Inheriting the default would reduce them.

### 1.3 Disruption risk of the upgrade itself

| Change | Disruption | Mitigation |
| --- | --- | --- |
| Controller resources, priority | Controller pod restarts once | None needed; seconds of controller downtime, no workload impact |
| AMI selection moves to `alias` | **One paced node roll** if the alias resolves to a different image than nodes currently run | Pin `ami_alias` to the current AMI version to defer it, then move the pin deliberately later |
| Karpenter `1.9` to `1.14` | CRD chart upgraded first; historically has needed manual `kubectl patch` in some setups | Apply in a non-production cluster first |
| Consolidation to `Balanced`/15m | Less churn, no disruption | None |
| Disruption windows | Consolidation pauses during the window | Confirm the window matches local traffic — Phase 2 |

Apply to development or staging first, confirm Phase 0 checks now read healthy, then promote.

---

## Phase 2 — Configure for the cluster's region and timezone

**Entry gate**: Phase 1 applied and verified.

### 2.1 Disruption windows are UTC only

Karpenter has **no timezone support**. Schedules are always interpreted in UTC. The module default protects
`0 6 * * mon-fri` for `12h`, meaning **06:00–18:00 UTC**, which suits central Europe in summer and nothing else.

Pick the window from where the cluster's users are, not where the cluster is hosted.

| Users in | Local business hours | Winter (standard) | Summer (DST) | Recommended single window |
| --- | --- | --- | --- | --- |
| Central Europe (CET/CEST) | 08:00–20:00 | 07:00–19:00 UTC | 06:00–18:00 UTC | `0 6 * * mon-fri`, `13h` |
| UK (GMT/BST) | 08:00–20:00 | 08:00–20:00 UTC | 07:00–19:00 UTC | `0 7 * * mon-fri`, `13h` |
| US East (EST/EDT) | 08:00–20:00 | 13:00–01:00 UTC | 12:00–00:00 UTC | `0 12 * * mon-fri`, `13h` |
| US West (PST/PDT) | 08:00–20:00 | 16:00–04:00 UTC | 15:00–03:00 UTC | `0 15 * * mon-fri`, `13h` |
| Armenia / Gulf (UTC+4) | 08:00–20:00 | 04:00–16:00 UTC | same | `0 4 * * mon-fri`, `12h` |
| India (UTC+5:30) | 08:00–20:00 | 02:30–14:30 UTC | same | `30 2 * * mon-fri`, `12h` |
| Australia East (AEST/AEDT) | 08:00–20:00 | 22:00–10:00 UTC | 21:00–09:00 UTC | `0 21 * * sun-thu`, `13h` — see below |

**Why 13h rather than 12h** for regions that observe daylight saving: the local window shifts by an hour twice
a year while the cron does not. A 13-hour window covers both offsets, at the cost of one extra protected hour
in one half of the year. Use 12h only where there is no DST.

**Windows crossing midnight UTC are fine** — the schedule is the opening time and the duration runs past it.

**But the cron weekday refers to the UTC opening day, not the local one.** For Australia East the window
opens at 21:00 UTC, which is already 07:00 the *next* day locally. `mon-fri` there would protect Tuesday to
Saturday local and leave Monday exposed — hence `sun-thu` in the table. Any region whose UTC opening time
falls on a different local date needs the cron shifted by a day. The European, UK, US and Asian rows above
all open on the same local day and need no shift.

Verify before applying: convert the opening time to local and confirm both the hour and the weekday.

**A recorded incident evicted replicas at 19:17 UTC**, just outside the default window (21:17 local). If your
traffic runs into the evening, extend `duration`.

```hcl
karpenter = {
  disruption_windows = [
    {
      schedule = "0 12 * * mon-fri"           # US East
      duration = "13h"
      reasons  = ["Drifted", "Underutilized"] # "Empty" stays allowed: removing an empty node disrupts nothing
      nodes    = "0"
    }
  ]
}
```

### 2.2 Remove any always-on `nodes: "0"` budget

If Phase 0 check 0.5 showed a budget of `nodes: "0"` with **no** `schedule` or `duration`, it is always
active. That does not reduce churn — it stops all voluntary disruption permanently, including AMI drift
remediation. One cluster carried it on four of five pools and had nodes 33 to 102 days old still running the
previous kubelet minor version.

**Remove it.** The module concatenates window budgets with existing ones, and budgets resolve
most-restrictive-wins, so an always-on `nodes: "0"` keeps winning and the windows do nothing.

> **Disruption note**: removing it lets consolidation and drift remediation resume, so expect node
> replacement to begin. That is the point, but it means the first apply after removal is the busiest.
> Do it outside traffic hours, with the window configured first so it is bounded.

### 2.3 A configuration trap worth knowing

Terraform **silently drops** object attributes that the target type does not declare. There is no error at
validate, plan or apply. If you write:

```hcl
resource_configs_defaults = {
  limits = { cpu = 11 }        # WRONG -- must be nested under `default`
}
```

the `limits` key is discarded and the module uses its own default of `cpu = 1000`. Two examples in this
repository carried exactly this and had been running a ceiling 90x higher than intended. Correct form:

```hcl
resource_configs_defaults = {
  default = {
    limits = { cpu = 11 }
  }
}
```

The module now rejects unexpected top-level keys here, so this specific mistake fails loudly. The general
lesson still applies to any `any`-typed input: after changing one, confirm the value actually took effect
rather than assuming a clean apply means it did.

### 2.4 Protected capacity

Enable it if the cluster runs an ingress controller, monitoring, or any single-replica or stateful workload:

```hcl
karpenter = {
  protected_node_pool = {
    enabled = true
    limits  = { cpu = 20 }
  }
}
```

Costs on-demand capacity. Workloads must opt in — Phase 4.

---

## Phase 3 — Workload configuration (`dasmeta/base` chart)

**Entry gate**: base chart `0.4.0` or newer.

### 3.1 What you get for free

At a replica floor of 2 or more, a PodDisruptionBudget is created automatically with `maxUnavailable: 1`.
Below 2, none is created — correctly, since a budget over a single replica either blocks every drain or
protects nothing. **Do not configure a PDB manually unless you have a specific reason.**

### 3.2 The single most common mistake

**Never set `pdb.minAvailable` equal to `autoscaling.minReplicas`.**

At the replica floor that permits **zero** evictions. It blocks node consolidation, blocks spot replacement
drains, and makes EKS node group upgrades **fail** on pod eviction. The symptom looks like Karpenter or the
cluster upgrade being stuck, nowhere near the service that caused it. The chart now refuses to render such a
budget, which is why some existing values files will start failing — that failure is the fix working.

### 3.3 Recommended per-service values

```yaml
autoscaling:
  enabled: true
  minReplicas: 2          # below 2, no disruption protection is possible at all
  maxReplicas: 10

terminationGracePeriodSeconds: 45   # must exceed the preStop sleep plus real shutdown time

resources:
  requests:               # karpenter provisions capacity from REQUESTS; missing ones cause under-provisioning
    cpu: 50m              # and slow recovery after every disruption
    memory: 64Mi

readinessProbe:           # takes a pod out of service without killing it
  initialDelaySeconds: 5
  failureThreshold: 1
livenessProbe:            # keep shallow and slower than readiness -- an aggressive one turns a blip into a rollout
  initialDelaySeconds: 15
  failureThreshold: 5
```

Defaults you do not need to set: `pdb` (derived), `spread` (on, node-level, soft), `defaultLifecycle.preStop`
(5s sleep so the pod IP leaves the load balancer before the container stops).

### 3.4 Single-replica services

A single-replica service cannot be protected by a PDB. Either raise it to 2, or move it to protected capacity
(3.5). There is no third option — this is a genuine gap, not a configuration oversight.

### 3.5 Pinning a workload to protected capacity

Both parts are required:

```yaml
tolerations:                                  # makes protected nodes ELIGIBLE
  - key: "dasmeta.io/protected"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"

nodeSelector:                                 # is what actually keeps it OFF spot
  karpenter.sh/capacity-type: on-demand
```

With only the toleration the pod can still land on spot and the protection is silently absent.

### 3.6 `do-not-disrupt` is a last resort

```yaml
podAnnotations:
  karpenter.sh/do-not-disrupt: "true"
```

Use only for a workload that genuinely cannot move and has no HA story — a single-writer database, a
long-running job that cannot resume. The node then stops receiving AMI patches and stops being consolidated,
and you must disrupt it by hand during upgrades. Prefer replicas plus a PDB.

---

## Phase 4 — Third-party charts

**Entry gate**: Phase 3 applied to first-party services.

The `dasmeta/base` guardrails do not apply to charts you did not deploy through it. These need manual review,
and they are where the worst findings have been.

### 4.1 Monitoring stacks

**Three separate clusters, three different clients, were found running `grafana-mysql` on spot capacity.**
That is a shared chart default, not three coincidences. One of them additionally had a PDB permitting zero
evictions on it — so the pod could be killed involuntarily by a spot reclaim, while no voluntary drain of its
node could ever complete.

Check and fix, in this order:

1. Any database or stateful pod on spot — move to protected capacity (3.5).
2. Any PDB with `disruptionsAllowed: 0` — Phase 0 check 0.7.
3. Prometheus with RWO storage and a single replica — slow volume reattach on eviction causes monitoring gaps
   during exactly the incidents you need visibility into.
4. `kube-state-metrics` — when it is evicted, alerts go stale and incidents look worse or resolve falsely.

### 4.2 Ingress controllers

At least 2 replicas, on protected capacity. An ingress controller on a reclaimed spot node takes out
everything behind it, and the resulting Route53 health-check dips have repeatedly been misdiagnosed as
application faults.

---

## Phase 5 — Observability

**Entry gate**: none, but most useful once Phase 1 is applied.

Alert on these, in priority order:

| Signal | Threshold | Why |
| --- | --- | --- |
| SQS `ApproximateAgeOfOldestMessage` on the interruption queue | > 60s | The spot notice is 120s. Sustained age above it means a drain **will** be missed. Reached 179s during a real incident |
| Karpenter controller restarts / `OOMKilled` | any | With correct resources this should be flat. Any restart means the memory limit needs raising for this cluster's size |
| Deployment ready replicas below desired | > 2 min | Catches both eviction storms and blocked drains |
| Pending pods by reason | > 5 min | Distinguishes "no capacity" from "cannot schedule" |
| Node registration time | > 5 min | Slow registration extends every recovery |

Aggregate alert queries by workload identity (`namespace`, `deployment`) rather than scrape-target labels
(`instance`, `pod`, `endpoint`). Stale `kube-state-metrics` series during node churn otherwise keep alerts
firing after recovery.

---

## Quick reference: symptom to cause

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Node stuck `Deleting` / drain never finishes | A PDB permitting zero evictions | 0.7 |
| Node group upgrade fails on pod eviction | Same | 0.7 |
| 502/504 burst during node replacement | No PDB, or `preStop` too short | 0.8, 3.3 |
| Service drops to zero replicas briefly | No PDB on a multi-replica service | 0.8 |
| Nodes far older than expected, stale kubelet | Always-on `nodes: "0"` plus `expireAfter: Never` | 0.5, 2.2 |
| Every node replaced at once, unprompted | AMI selected by `id` from a sampled instance | 0.4 |
| Spot reclaim with no drain at all | Controller unavailable — OOMKilled or single replica restarting | 0.1, 0.10 |
| Monitoring gaps during incidents | Prometheus or `kube-state-metrics` evicted | 0.9, 4.1 |
| Karpenter preempted under node pressure | Priority class demoted from `system-cluster-critical` | 0.2 |

---

## What this guide does not cover

- Pod IP exhaustion and subnet capacity affecting node placement.
- Orphaned NodeClaims and detached volumes.
- Application-level probe and health-check tuning beyond the disruption-relevant parts.
- Upgrading the underlying `terraform-aws-modules` EKS module to v21, which is a separate migration.
