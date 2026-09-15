# EKS Stability and Spot Cost Guide

**Who this is for**: delivery and support engineers, and the AI agents working on their behalf.

**What it is for**: running a spot-backed EKS cluster that is cheap *and* does not drop traffic. Those two
goals pull against each other, and most of this document is about where the line sits.

**Scope**: one cluster at a time, in the order given. The order matters — several steps are unsafe before the
one preceding them.

Every recommendation addresses a failure mode seen in practice. Where a step can cause disruption, the risk is stated
on the step rather than buried in a footnote.

---

## How to use this document

Work top to bottom. Each phase has an **entry gate** — do not start it until the gate passes. Each step says
what changes, why, what can go wrong, and how to verify.

### Every script this module ships, and when to run it

| script | changes anything? | when |
| --- | --- | --- |
| `eks-assess.sh` | **no** | first, always. Zero arguments — it discovers cluster, region and account from your kube context. Its output decides which later phases apply |
| `eks-config-lint.sh <eks.yaml>` | **no** | alongside the assessment, on the setup's config. Needs no cluster access at all, so it works before you have credentials |
| `eks-destroy-prep.sh --check-only` | **no** | when a `terraform destroy` fails on a security group, and before one as a precaution. Reports what still holds it |
| `eks-destroy-prep.sh` | **yes** | before a planned teardown. Deletes the objects that own AWS resources and waits for those resources to actually go |
| `eks-destroy-prep.sh --delete-orphan-enis` | **yes** | to clear leaked CNI interfaces, which hold IPs on a live cluster and block a destroy later. Safe on a running cluster |

`check-no-local-paths.sh` is a CI guard for this repository, not a tool for a cluster.

Nothing else is needed. If a procedure here reads as though it wants a script that does not exist, it is the
procedure that is wrong — say so rather than writing one.

Start with the two scanners. They tell you which of the later steps actually apply to the cluster in front of
you, and neither changes anything:

```sh
./scripts/eks-assess.sh                       # live cluster; needs only a kube context and an AWS session
./scripts/eks-config-lint.sh path/to/eks.yaml # setup config; needs no access at all
```

### If you are an AI agent

- Run the assessment **first** and report what it found before proposing any change. The output determines
  which later steps apply.
- Do not batch phases. Several steps are destructive if their precondition is unmet.
- Ask before applying anything from Phase 2 onward.
- Never infer a cluster's state from its config file, or its config from its live state. They drift, and the
  drift is often the finding. One cluster in this fleet has a config declaring one controller replica while
  running two.
- When you report a finding, give the evidence (the command output), not a summary of it.
- Use only the scripts in the table above. They are the whole toolset; there is no other entry point, and a
  step that seems to need one it does not have is a defect in this document.

### The shape of the problem

Most of these incidents reduce to one of five things:

1. **The node autoscaler is unavailable when capacity is reclaimed.** Nothing drains, and every reclaimed node
   becomes an abrupt kill. No other setting compensates.
2. **A workload has no PodDisruptionBudget**, so one node drain removes every replica at once.
3. **A workload has a PodDisruptionBudget that permits zero evictions**, which blocks drains entirely and
   fails cluster upgrades — while presenting as the autoscaler being stuck.
4. **A stateful or single-replica workload sits on reclaimable capacity**, where nothing can protect it.
5. **The instance shape is wrong for the workload**, so nodes are interrupted more often than they need to be.

Everything below is a way of preventing one of those.

---

## Phase 0 — Assess (read-only, always safe)

**Entry gate**: none. Run this on any cluster, any time.

Collect all of it before changing anything. Later phases branch on these answers.

**Fastest path**, both read-only and both zero-argument:

```sh
./scripts/eks-assess.sh                        # live cluster
./scripts/eks-config-lint.sh <env>/eks.yaml    # the setup config, no cluster access needed
```

The assessment discovers cluster, region, account and interruption queue from the kube context and the
autoscaler deployment, so an AWS session and a kube context are all it needs. The linter reads a config file
and flags the same problems before they reach a cluster, so it works in CI and against any setup repository.

Run **both**. They disagree when config has drifted from live, and that disagreement is itself a finding.

The individual commands are kept below so you can run any one on its own, and so the scripts are auditable
rather than a black box.

```sh
# C1 -- controller sizing, replica count, restarts, priority and version
kubectl -n karpenter get deploy karpenter \
  -o jsonpath='{.spec.replicas}{"  "}{.spec.template.spec.containers[0].image}{"  "}{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter -o json \
  | jq -r '.items[] | "restarts=\(.status.containerStatuses[0].restartCount) lastTerminated=\(.status.containerStatuses[0].lastState.terminated.reason // "none") priority=\(.spec.priorityClassName)"'

# C3 -- controller-eligible nodes: managed node group only, and their zones
kubectl get nodes -L topology.kubernetes.io/zone,karpenter.sh/nodepool

# D1 -- AMI selection
kubectl get ec2nodeclass -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.amiSelectorTerms}{"\n"}{end}'

# D2 -- disruption posture per node pool
kubectl get nodepool -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.disruption}{"  expireAfter="}{.spec.template.spec.expireAfter}{"\n"}{end}'

# D4 -- nodes drifted but correctly held back by a protection
kubectl get nodeclaims -o json | jq -r '.items[]
  | select((.status.conditions // [])[] | select(.type == "Drifted" and .status == "True"))
  | .status.nodeName // .metadata.name'

# E1 -- budgets that permit nothing
kubectl get pdb -A -o json \
  | jq -r '.items[]|"\(.metadata.namespace)/\(.metadata.name) allowed=\(.status.disruptionsAllowed) expected=\(.status.expectedPods)"' \
  | grep 'allowed=0'

# E2 -- multi-replica workloads, to compare against which namespaces have any PDB
kubectl get deploy -A -o json | jq -r '.items[]|select(.spec.replicas>=2)|"\(.metadata.namespace)/\(.metadata.name)"' | sort

# E4 -- stateful and singleton workloads sitting on spot capacity
kubectl get nodes -l karpenter.sh/capacity-type=spot -o name | sed 's|node/||' > /tmp/spot.txt
kubectl get pods -A -o json | jq -r '.items[]|select(.spec.nodeName!=null)|"\(.metadata.namespace)/\(.metadata.name) \(.spec.nodeName)"' \
  | grep -Ff /tmp/spot.txt | grep -E 'mysql|postgres|prometheus|grafana|redis|elastic|kafka|kube-state-metrics|ingress'

# F1 -- instance family mix (t = burstable)
kubectl get nodes -o json | jq -r '
  [.items[] | (.metadata.labels["node.kubernetes.io/instance-type"] // "unknown")]
  | group_by(.) | map({t: .[0], n: length}) | sort_by(-.n)[] | "\(.n)x \(.t)"'

# G1 -- is the interruption queue keeping up?
# CloudWatch caps one call at 1440 datapoints: 30 days at 3600s is 720, well under. A wide period is safe
# because the statistic is Maximum, so a 300s spike still shows in its hour.
aws cloudwatch get-metric-statistics --namespace AWS/SQS \
  --metric-name ApproximateAgeOfOldestMessage \
  --dimensions Name=QueueName,Value=Karpenter-<cluster-name> \
  --start-time $(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 --statistics Maximum --region <region> --output table
```

### Reading the results

Identifiers match the section headings printed by `./scripts/eks-assess.sh`, so a finding can be traced
straight back to the check that produced it.

| Check | Healthy | Exposed |
| --- | --- | --- |
| C1 | memory limit >= `1Gi`, `replicas: 2`, no `OOMKilled`, `system-cluster-critical`, image `1.14.x` | `256Mi`, or `replicas: 1`, or any OOMKill, or priority `high`, or `1.9.x` |
| C3 | 2+ nodes with an EMPTY `NODEPOOL` column, in 2+ zones | fewer than 2 — see the trap below |
| D1 | `alias: al2023@...` | `id: ami-...` — replacement can trigger with no config change |
| D2 | `Balanced`, a scheduled budget | `WhenEmptyOrUnderutilized` with a short `consolidateAfter`, or an always-on `nodes: "0"` |
| D4 | no output, or nodes cleared within your patching tolerance | nodes held for longer — a human needs to run that workload's replacement flow (3.8) |
| E1 | no output | any row — that workload blocks node drains and node group upgrades |
| E2 | every entry has a PDB | entries with none lose all replicas to one drain |
| E4 | no output | stateful or singleton workloads on reclaimable capacity |
| F1 | `c`, `m` or `r` families | `t` families — burstable, throttles under sustained load, higher interruption rate |
| G1 | every datapoint `0.0` | sustained above ~60s; above 120s means drains are being missed |

The full script covers more than this list: cluster and addon baseline (A1–A3, B1–B2), controller sizing
context (C2), node age (D3), PDBs the base chart guard will reject (E3), singleton StatefulSets (E5),
workloads with no resource requests (E6), single-replica deployments (E7), and CPU-versus-memory reservation
balance (F2). The commands above are the ones most often run on their own.

**The trap in C3**: Karpenter-managed nodes cannot host the Karpenter controller. The chart sets a
`karpenter.sh/nodepool DoesNotExist` node affinity, so only managed-node-group nodes are eligible. A cluster
with many nodes across three zones can still be unable to schedule a second replica when most were Karpenter-provisioned.
Count rows where the `NODEPOOL` column is **empty**, not total nodes.

**Reading G1**: the metric publishes only when the queue has activity, so a handful of datapoints across
several days is normal. An all-zero result means messages are consumed as fast as they arrive. Check a window
that actually contains a known incident before concluding a cluster is fine — a window starting after the
event shows only the recovered state.

---

## Phase 0.5 — Fix what blocks every later phase

**Do this before changing anything else.** A PodDisruptionBudget that permits zero evictions is not just a
defect to fix eventually — it blocks the phases that follow, and it does so in two different ways that are
easy to meet separately and hard to diagnose together.

**It fails the module upgrade.** Phase 1 replaces the managed node group: the system taint and the instance
type both change, and a replacement drains every node in that group. An eviction the budget forbids does not
wait — it *fails* the node group update. You get a half-replaced group and an error naming pod eviction,
nowhere near the release that caused it.

**It fails the chart upgrade.** Phase 3 bumps the base chart to 0.4.0, which refuses to render such a budget.
That failure stops the whole deploy, which is correct, but a deploy that fails halfway through a migration
is a worse place to be than one that never started.

**And it blocks the node replacement those phases exist to deliver.** Once the module upgrade widens the
instance requirements, nodes on the old shapes are marked drifted — and a zero-eviction budget on any pod
they host means they can never be replaced. The cluster ends up configured correctly and unable to act on
it. This was observed on a test upgrade: two nodes drifted, one at 96% memory, held indefinitely by a single
bad budget on an unrelated release.

```bash
# Everything E1 lists, except those marked DELIBERATE
./scripts/eks-assess.sh | sed -n '/E1\./,/E2\./p'

# And what E3 predicts will be refused by the chart upgrade
./scripts/eks-assess.sh | sed -n '/E3\./,/E4\./p'
```

### Where this work actually happens

**Not in the EKS terraform.** Applications are deployed from their own repositories by their own pipelines,
so the offending values live there and the change is made by the team that owns each service. The cluster
work in the later phases cannot proceed until those merge, which makes this the item to raise first and the
one with the longest lead time — it is a set of pull requests against other people's repositories, not a
terraform apply you control.

What to ask each owning team for, as one change:

1. **Bump `dasmeta/base` to `0.4.0` or later.**
2. **Delete the `pdb` block.** On 0.4.0 a safe budget is what you get by *not* configuring one, so the
   corrected values are shorter than what they replace.

Both in the same pull request, and in that combination. Bumping the chart while leaving a zero-eviction
budget in place makes the render fail, so a version bump on its own turns a latent problem into a broken
deploy. Removing the block first and bumping later works but leaves the service with no budget in between.

Where the budget is deliberate — a workload rolled by hand that automation must never evict — the change is
`pdb.allowZeroEvictions: true` instead of deleting the block. That keeps the behaviour and records that it
is intended, and the rendered budget then carries an annotation so the next person to find a stuck drain
can see it was a decision.

Check the values before raising any of this. E3 reads the live object, and a release that already sets
`allowZeroEvictions` looks identical to one that needs correcting — asking a team to "fix" a service that
was already right costs credibility you will want later.

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
| AMI selection moves to `alias` | **One paced node roll** if the alias resolves to a different image than nodes currently run | Pin `resource_configs_defaults.default.nodeClass.amiAlias` to the current version to defer it, then move the pin deliberately later |
| Karpenter `1.9` to `1.14` | CRD chart upgraded first; historically has needed manual `kubectl patch` in some setups | Apply in a non-production cluster first |
| Consolidation to `Balanced`/15m | Less churn, no disruption | None |
| System node group tainted `CriticalAddonsOnly` | **Rolling replacement of the managed node group** | Maintenance window; see 1.4 |
| System instance type `t3.large` → `t3.medium` | Same rolling replacement | Apply in the SAME change as the taint so the group is replaced once, not twice |
| Disruption windows | Consolidation pauses during the window | Confirm the window matches local traffic — Phase 2 |

**What `@latest` means after the upgrade.** Node replacement becomes **continuous and unattended** — it is not
tied to running Terraform. Karpenter resolves the alias itself and re-checks AMI data roughly every minute
(`amiRefreshInterval`, chart default `1m`). When AWS publishes a new EKS-optimised AMI, typically every few
weeks and sooner for CVEs, Karpenter marks nodes `Drifted` within about a minute and starts replacing them.

This is intended: it is how nodes receive OS and kernel patches without anyone remembering to act. It is safe
because drift is *voluntary* disruption, so the disruption budget paces it and the protected window keeps it
out of your traffic hours. The old behaviour changed only on apply, but chose the image unpredictably and
drifted every node at once when it did — rarer, but far less controlled.

If your change control requires a human to schedule node replacement, pin the version instead
(`nodeClass = { amiAlias = "al2023@v20240807" }`) and put a recurring task in place to move the pin. Pinning stops patching
until someone acts, so it is a trade, not a free safety improvement.

Apply to development or staging first, confirm Phase 0 checks now read healthy, then promote.

### 1.4 The system node group taint

From `2.30.0` the managed node groups are tainted `CriticalAddonsOnly=true:NoSchedule` by default whenever
Karpenter is enabled.

**Why it is a default rather than a recommendation.** These nodes exist to host the Karpenter controller,
CoreDNS and the CSI controllers. Without the taint, application pods schedule onto them and compete with the
very controller that provisions their capacity — on a two-node group that is how the controller ends up
starved, which is the first link in the incident chain this guide exists to break. It was already the
documented recommendation and was being forgotten in practice.

**What stays on system nodes**: the Karpenter controller, the EKS CoreDNS addon and the EBS CSI controller,
all of which tolerate `CriticalAddonsOnly` out of the box, plus the AWS Load Balancer Controller. **What
moves to Karpenter capacity**: cert-manager, external-dns, KEDA, service mesh, and any in-cluster ingress
controller. That is the intent, not a side effect.

**Two safeguards worth knowing:**

- It is applied **only when Karpenter is enabled**. Without Karpenter there is nowhere else for workloads to
  run, so tainting the only node groups would leave the cluster unable to schedule anything.
- A node group that declares its own `taints` is left exactly as written.

> **Disruption note**: adding a taint is a node group update, so it causes a **rolling replacement** of the
> managed node group. Do it in a maintenance window. `NoSchedule` does not evict running pods, so application
> pods currently on system nodes stay until they are next rescheduled and then migrate — the change is
> gradual, but the node replacement itself is not.

Opt out where the isolation is not worth the capacity, typically development and test:

```hcl
node_groups_system_taint = { enabled = false }
```

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

**Evictions have been seen just outside a window like this**, in the hour after it closes. If your
traffic runs into the evening, extend `duration`.

```hcl
karpenter = {
  resource_configs_defaults = {
    default = {
      disruption = {
        budgets = [
          { nodes = "10%" },                        # never move more than a tenth of the pool at once
          {
            nodes    = "0"                          # block the reasons below while the window is open
            schedule = "0 12 * * mon-fri"           # US East
            duration = "13h"
            reasons  = ["Drifted", "Underutilized"] # "Empty" stays allowed: an empty node disrupts nothing
          },
        ]
      }
    }
  }
}
```

Every field of `resource_configs_defaults` is individually optional, so setting `disruption.budgets` keeps
`consolidationPolicy` and `consolidateAfter` on the module defaults rather than dropping them.

### 2.2 Remove any always-on `nodes: "0"` budget

If assessment section D2 showed a budget of `nodes: "0"` with **no** `schedule` or `duration`, it is always
active. That does not reduce churn — it stops all voluntary disruption permanently, including AMI drift
remediation. Clusters have carried it on most pools, leaving nodes many months old still running the
previous kubelet minor version.

**Remove it.** Protection windows are ordinary entries in the same `budgets` list, so an always-on
`nodes: "0"` sits alongside them and wins — budgets resolve most-restrictive-wins. Adding a window changes
nothing until the always-on block is gone.

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

**When you need it.** Add this pool only if the cluster runs something that cannot survive its node
disappearing:

| Add it | Skip it |
| --- | --- |
| Metrics store and its database | Everything stateless with 2+ replicas |
| Single-replica or stateful services | Batch and queue workers that can restart |
| An in-cluster ingress controller, if one is unavoidable | Ingress served by an ALB, which is outside the cluster |

If nothing on the cluster fits the left column, delete the pool — it is on-demand capacity you are paying
for and nothing needs. If something does, this is the fix for the pattern where a routine spot reclaim took
out monitoring and made every co-occurring incident harder to diagnose.

There is no special input for this — it is an ordinary node pool with an on-demand requirement and a taint:

```hcl
karpenter = {
  resource_configs = {
    nodePools = {
      general = { weight = 1 }

      # The whole pool. Referencing the `on-demand` node class brings the preset with it.
      on-demand = { template = { spec = { nodeClassRef = { name = "on-demand" } } } }
    }
  }
}
```

The preset supplies `weight = 50`, the on-demand requirement, an instance filter admitting burstable while
excluding the specialised families, a memory floor above the 2GiB shapes, the `dedicated=on-demand` taint,
`WhenEmpty` consolidation and the standard capacity ceiling. Override any of them on the pool.

**Why `weight` is in the preset rather than left to you.** It orders pools when more than one could satisfy
the same pod, highest first, and a pool with no weight counts as `0` — so with `general` at `1` and this
left unset, the on-demand pool ends up *lower* priority, the opposite of the intent. The number is arbitrary
beyond the ordering; the valid range is 1–100.

It matters even though the workload also selects on-demand (section 3.6), because `general` accepts both
capacity types and can satisfy an on-demand selector itself. Without the higher weight, a tolerating pod can
land on an on-demand node in `general` — right capacity type, but an **untainted** node that ordinary
workloads will then share, so the isolation is quietly lost.

**It declares its own `budgets`**, which is what keeps the protection window off this pool. That is
deliberate: it should only ever lose a genuinely empty node, at any hour.

**Declare only what differs.** Requirements merge by *key*: a class default is kept unless the pool declares
the same key, in which case the pool's version replaces it. `capacity-type` above narrows the default
`["spot", "on-demand"]` to on-demand; instance category, generation, CPU and memory ranges and architecture
are all inherited. Re-stating a default is not just noise — it pins the pool to today's value, so it silently
stops following the module if that default ever changes.

Everything else is an ordinary node pool — adjust the taint key, add labels, point it at a different node
class. Nothing about it is special-cased.

Costs on-demand capacity. Workloads must opt in — Phase 4 and section 3.6.

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

### 3.4 Resource requests are not optional

The autoscaler provisions capacity from pod **requests**. A pod with none contributes nothing to that
calculation, so the cluster is under-provisioned by exactly the amount those pods actually use. The symptom is
pods pending after every disruption and recovery taking far longer than it should — which reads as an
autoscaler problem and is not one.

Assessment section E6 lists workloads missing requests. Set at least `cpu` and `memory` requests on
every container. Limits are a separate decision; requests are what scheduling and provisioning depend on.

### 3.5 Single-replica services

A single-replica service cannot be protected by a PDB. Either raise it to 2, or move it to on-demand capacity
(3.6). There is no third option — this is a genuine gap, not a configuration oversight.

### 3.6 Pinning a workload to on-demand capacity

Both parts are required:

```yaml
tolerations:                                  # makes on-demand nodes ELIGIBLE
  - key: "dedicated"
    operator: "Equal"
    value: "on-demand"
    effect: "NoSchedule"

nodeSelector:                                 # is what actually keeps it OFF spot
  karpenter.sh/capacity-type: on-demand
```

With only the toleration the pod can still land on spot and the protection is silently absent.

### 3.7 `do-not-disrupt` is a last resort

```yaml
podAnnotations:
  karpenter.sh/do-not-disrupt: "true"
```

Use only for a workload that genuinely cannot move and has no HA story — a single-writer database, a
long-running job that cannot resume. The node then stops receiving AMI patches and stops being consolidated,
and you must disrupt it by hand during upgrades. Prefer replicas plus a PDB.

### 3.8 Protections are absolute, and that is deliberate

A node hosting a pod with a blocking PodDisruptionBudget or the `karpenter.sh/do-not-disrupt` annotation is
**never replaced** by voluntary disruption. It keeps its older AMI until a human moves the workload. That is
the intended behaviour, not a fault to be worked around.

The module leaves `resource_configs_defaults.default.terminationGracePeriod` unset for exactly this reason. Setting it does more than bound a
drain that has already begun — Karpenter's docs state that a node with `do-not-disrupt` pods is
"conditionally excluded from Drift" and "if the Node's owning NodeClaim has a `terminationGracePeriod`
configured, it will still be eligible for disruption via drift", after which pods are force-deleted including
"pods with blocking pod disruption budgets or the `karpenter.sh/do-not-disrupt` annotation".

In other words, setting it silently converts both protections from a guarantee into a delay. A single-writer
database annotated `do-not-disrupt` would be killed partway through an AMI roll — the opposite of what the
annotation promises. A workload marked always-up should stay up, and running an older AMI for a few days is
the cheaper problem.

**The trade-off this creates, and how to handle it.** Those nodes stop receiving AMI patches, so somebody has
to act. That is a scheduling problem, not an automation problem:

1. **Assessment section D4** lists every node that is drifted but held back, and names what is holding it —
   a `do-not-disrupt` pod, or a PDB currently permitting zero evictions.
2. **A PDB permitting zero evictions is a defect.** Fix it (section 3.2); it was never protecting anything.
3. **A `do-not-disrupt` annotation is a deliberate choice.** It needs that workload's own replacement flow —
   typically cool the workload down, replace the node, bring it back. Run it on your schedule.
4. **Watch how long nodes sit in D4.** Past your patching tolerance it needs escalating. It will not resolve
   on its own, and that is by design.

Do not reach for `terminationGracePeriod` to make this go away. It does not solve the problem, it just
moves the outage to a time nobody chose.

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

1. Any database or stateful pod on spot — move to on-demand capacity (3.6).
2. Any PDB with `disruptionsAllowed: 0` — assessment section E1.
3. Prometheus with RWO storage and a single replica — slow volume reattach on eviction causes monitoring gaps
   during exactly the incidents you need visibility into.
4. `kube-state-metrics` — when it is evicted, alerts go stale and incidents look worse or resolve falsely.

### 4.1b Admission webhook controllers

Any component that registers a webhook with `failurePolicy: Fail` -- kyverno, KEDA, cert-manager, a service
mesh injector -- holds a veto over the API calls it matches. When it has no healthy backend, those calls are
rejected rather than skipped. One replica means one eviction is enough, and the rejections usually land on pod
creation across the whole cluster, so the workload that cannot start looks like the fault and the real cause
is several layers away.

Give these 2+ replicas, or place them on on-demand capacity, and check that their PDB permits an eviction.
Assessment section B3 lists every `Fail` webhook alongside how many backends it currently has.

The same property makes them awkward to remove: the pods go, the webhook stays registered, and the cleanup it
needs is rejected by itself. That presents as a `helm delete` or `terraform destroy` that never finishes.
Delete the webhook configurations first, then the release.

### 4.2 Ingress

Prefer an AWS load balancer over an in-cluster ingress controller. An `Ingress` with class `alb` and
target-type `ip` puts the load balancer outside the cluster and sends traffic straight to pod IPs, so there
is no ingress data plane left to reclaim. The AWS Load Balancer Controller only reconciles Ingress objects
into ALB configuration and is not in the request path. This is also the direction of travel: ingress-nginx
is retired upstream, so new setups should not adopt it.

Where an in-cluster controller is unavoidable, it needs all three: at least 2 replicas, a
`topologySpreadConstraints` entry on `kubernetes.io/hostname` so the replicas cannot share a node, and
protected on-demand capacity. Replicas alone protect nothing -- two of them on one reclaimed node fail
together, and the resulting Route53 health-check dips have repeatedly been misdiagnosed as application
faults.

---

## Upgrading the Kubernetes version

Two things behave differently from what most people expect, and both look like a stalled upgrade.

**The node group upgrade is a full drain, so it is where bad budgets surface.** Every node is cordoned and
drained in turn. A PodDisruptionBudget permitting zero evictions does not slow this down, it **fails** it,
and the error names pod eviction rather than the budget. If you upgrade nothing else first, run assessment
section E1 and fix every zero-eviction budget before starting.

**Raising the control plane drifts the entire Karpenter fleet at once.** The `al2023@latest` alias resolves
the AMI for the cluster's Kubernetes version, so the target image for every node changes the moment the
control plane moves. This is the largest single drift event the configuration will ever produce.

That drift is voluntary disruption, so the budgets and the disruption window apply to it. Inside the window
the roll is **blocked**, and the cluster sits with an upgraded control plane and nodes still on the previous
kubelet. That is correct, within the supported version skew, and deliberate — but it reads as a stuck
upgrade to anyone who does not know the window is there.

Confirm which state you are in rather than guessing:

```bash
kubectl -n karpenter port-forward deploy/karpenter 8080:8080 >/dev/null 2>&1 &
sleep 3; curl -s localhost:8080/metrics | grep allowed_disruptions
```

`0` against `Drifted` means the window is holding the roll and it will proceed when the window closes.
Section D3 shows the kubelet spread while that is true; D4 lists anything held back for a different reason.

If the nodes must roll now, the options in order of preference are: wait for the window; narrow the window
for this maintenance; or temporarily remove the `Drifted` reason from the budget. Do not delete the budget
entirely — that also removes the concurrency limit, and rolling every node at once during an upgrade is how
a controlled upgrade becomes an outage.

**A note on system nodes.** If `max_size` equals `desired_size`, EKS cannot surge and replaces the managed
node group one node at a time. On a two-node group that means a single node for part of the upgrade, so one
Karpenter replica is `Pending` until the replacement joins. The surviving replica keeps reconciling. Raise
`max_size` to `desired + 1` before the upgrade if you want both replicas schedulable throughout.

---

## Phase 5 — Observability

**Entry gate**: none, but most useful once Phase 1 is applied.

Alert on these, in priority order:

| Signal | Threshold | Why |
| --- | --- | --- |
| SQS `ApproximateAgeOfOldestMessage` on the interruption queue | > 60s | The spot notice is 120s. Sustained age above it means a drain **will** be missed. Reached the notice period during a real incident |
| Karpenter controller restarts / `OOMKilled` | any | With correct resources this should be flat. Any restart means the memory limit needs raising for this cluster's size |
| Deployment ready replicas below desired | > 2 min | Catches both eviction storms and blocked drains |
| Pending pods by reason | > 5 min | Distinguishes "no capacity" from "cannot schedule" |
| Node registration time | > 5 min | Slow registration extends every recovery |
| Nodes drifted but not replaced | > your patching tolerance | A protection is correctly holding the node; it needs a human with the workload's replacement flow. Assessment section D4 names what is holding it |

Aggregate alert queries by workload identity (`namespace`, `deployment`) rather than scrape-target labels
(`instance`, `pod`, `endpoint`). Stale `kube-state-metrics` series during node churn otherwise keep alerts
firing after recovery.

---

## Spot cost optimisation without losing stability

Spot capacity is the point of this setup. The goal is not to use less of it, but to make its interruptions
survivable and less frequent.

### What actually reduces interruptions

**Instance flexibility is the biggest lever.** AWS reclaims from the pools under most pressure. The wider the
set of instance types a pool will accept, the more likely a replacement is available and the less often any
one type is reclaimed. Narrow requirements are the single most common cause of avoidable interruption.

**Avoid burstable instances for sustained workloads.** The `t` family is CPU-credit based: once credits are
exhausted it throttles to a fraction of its advertised vCPU, which surfaces as latency that looks like an
application fault. It also occupies the most contended spot pools. Because the autoscaler picks the *cheapest*
instance satisfying the constraints, a `t3.2xlarge` was very often what it picked before the default excluded
that family. Cheap per hour, expensive in incidents.

**Match the instance shape to the workload.** Assessment section F2 reports CPU and memory reservation per node. If CPU is consistently far higher than memory, nodes run out of CPU while paid-for memory sits idle:

| Reservation pattern | Instance category | Memory per core |
| --- | --- | --- |
| CPU much higher than memory | `["c"]` | 1:2 |
| roughly balanced | `["c", "m"]` | 1:2 and 1:4 |
| memory much higher than CPU | `["m", "r"]` | 1:4 and 1:8 |

The module default is `["c", "m", "r"]` — deliberately wide, because flexibility beats precision until you
have measured. Narrow it once F2 gives you a clear answer.

### What does not reduce interruptions

- **Disruption budgets and windows.** They gate *voluntary* disruption only. Reclamation is involuntary and is
  never delayed by them.
- **`karpenter.sh/do-not-disrupt`.** Same: voluntary only.
- **PodDisruptionBudgets.** They gate the eviction API. A reclaimed instance does not use it.

Those three protect against consolidation and upgrades. Nothing protects a workload from reclamation except
**not being on reclaimable capacity**.

### Where to spend on-demand

On-demand is the only real protection against reclamation, so spend it narrowly and deliberately:

| Workload | Placement | Why |
| --- | --- | --- |
| Node autoscaler controller | managed node group | If it is reclaimed while reclaiming, nothing drains |
| In-cluster ingress controllers, where unavoidable | protected on-demand | Reclaiming one takes out everything behind it; an ALB has no such exposure |
| Databases, single-replica stateful | protected on-demand | ReadWriteOnce volumes reattach slowly from a node that is already gone |
| Monitoring (metrics store, its database) | protected on-demand | Losing it during churn removes the visibility you need to diagnose the churn |
| Everything else | spot | This is the majority, and where the saving is |

Add the protected pool as a standard node pool (section 2.4), then opt workloads in with
**both** a toleration and a node selector — see 3.6. The toleration alone only makes the capacity eligible; it
does not keep the pod off spot.


**Burstable is not the only throttling shape.** The `flex` variants -- `c7i-flex`, `m8i-flex` and their
relatives -- are compute or general instances by category, so a `["c", "m", "r"]` filter admits them, and
karpenter picks the cheapest match. They deliver roughly a 40% CPU baseline with burst above it, which is
the same sustained-load profile the `t` family is excluded for. The module's defaults exclude them by family
name, because karpenter has no label for the behaviour; a new flex family is admitted until it is added to
that list.

**Do not pay twice.** Protected capacity is already on-demand, which is the premium you are choosing to pay.
Do not also pay for compute-optimised shapes there unless something on it needs them. The workloads that
belong on protected capacity -- a controller, a singleton, a small stateful service -- have the same low,
steady profile that makes burstable right for the system node group. The module's default requirements
exclude the `t` family because they are written for the general pool, where bulk workloads drive sustained
CPU and burstable throttles; that argument does not carry over to a couple of singletons.

Widen the protected pool's own requirements to admit burstable:

All of this is the `protected` preset, so declaring the pool is:

```hcl
resource_configs = {
  nodePools = {
    on-demand = { template = { spec = { nodeClassRef = { name = "on-demand" } } } }
  }
}
```

which resolves to the on-demand requirement, the burstable-friendly instance filter with its memory floor,
the `dedicated=on-demand` taint, weight 50, `WhenEmpty` consolidation and the standard capacity ceiling. Each is
overridable on the pool. The equivalent written out, if you need to change one of them:

```hcl
requirements = [
  { key = "karpenter.sh/capacity-type",            operator = "In", values = ["on-demand"] },
  { key = "karpenter.k8s.aws/instance-category",   operator = "In", values = ["t", "c", "m", "r"] },
  { key = "karpenter.k8s.aws/instance-generation", operator = "Gt", values = ["2"] },
  { key = "karpenter.k8s.aws/instance-memory",     operator = "Gt", values = ["3000"] },
]
```

The memory floor is not optional once the `t` family is admitted. Without it karpenter reaches 2GiB shapes
and will pick one -- observed picking a `t3a.small` on protected capacity. That is the same size ruled out
for the system node group, for the same two reasons: the VPC CNI allows only 11 pods on it, of which the
DaemonSets take about 5, and roughly 1.5GiB allocatable is thin for anything worth protecting. `3000` admits
`t3.medium` at 4GiB, the smallest shape that behaves, and costs nothing in the cases where karpenter would
have chosen something larger regardless.

The generation floor has to drop with it. The default of `>4` excludes the `t` family outright: `t3` is
generation 3, and `t4g` is arm64 so the architecture requirement removes it anyway. `>2` admits `t3`/`t3a`
while still keeping the pre-nitro generations out.

Reverse this for anything CPU-hungry that lands on protected capacity -- a metrics store under real load is
the usual example. Narrow that pool back to `["c", "m", "r"]`, or give the workload a pool of its own.
### The system node group

The autoscaler controller cannot run on nodes the autoscaler created — its chart sets a
`karpenter.sh/nodepool DoesNotExist` affinity. So a managed node group is required, and it needs:

- **2 nodes minimum, in 2 availability zones.** The chart also sets required hostname anti-affinity and a
  `DoNotSchedule` zone spread, so 2 replicas need 2 eligible nodes in 2 zones. Total cluster node count is
  irrelevant. A cluster can run many nodes across three zones and still not schedule a second
  replica, because 7 are autoscaler-provisioned and only 1 is eligible.
- **Small instances, and burstable is correct here.** These nodes carry a small, steady load — one controller
  replica, one CoreDNS, a CSI controller, the DaemonSets. That is exactly the profile burstable instances
  suit, and it is the opposite of the sustained-high load that makes them a poor choice for application
  nodes. The default is `t3.medium`.
- **Know where the default runs out.** Measured controller CPU scales at roughly **3m per cluster node**
  `t3.medium` sustains 400m before credits deplete and the other
  system pods take ~250m, so the default holds to roughly **50 cluster nodes**. Past that, or on any sign of
  credit exhaustion, move to non-burstable:

  ```hcl
  node_groups_default = { instance_types = ["c6a.large", "c6i.large"] }
  ```

- **Never `t3.small`**, at any cluster size. Two hard limits that do not depend on load: the VPC CNI allows
  only **11 pods** on it — `(3 ENIs × (4 IPs − 1)) + 2` — and the DaemonSets alone take about 5; and its
  ~1.5 GiB allocatable cannot hold the controller's memory limit alongside CoreDNS and the CSI controller.
  `t3.medium` gives 17 pods and 4 GiB, which fits with headroom.

## Leaked CNI network interfaces

This one costs you twice, and the expensive half happens while the cluster is running.

The VPC CNI allocates secondary network interfaces on each node to hand out pod IPs. When a node goes away
before the CNI detaches them -- every consolidation, every spot reclaim, every node group replacement -- the
interface is left behind in `available` state, attached to nothing. Nothing reclaims it. AWS does not
garbage-collect an available interface.

**On a running cluster** each orphan holds a private IP in its subnet. A cluster with heavy node churn
loses address space steadily, and the failure it eventually produces is pods that cannot be scheduled with
nothing in Kubernetes explaining why -- the subnet is full of addresses belonging to nodes that no longer
exist. This is the reason to care about it before any teardown.

**At teardown** they hold the node security group, and `terraform destroy` fails on it with
`DependencyViolation` fifteen minutes after the thing that caused it.

Assessment section G2 reports them. Remove them with:

```bash
./scripts/eks-destroy-prep.sh --delete-orphan-enis
```

Safe against a live cluster: it only removes interfaces that are `available` and unattached, which by
definition no pod is using.

**Why this is not automated in the module.** Two ways were considered and both are worse than the script. A
Terraform destroy-time provisioner would make the AWS CLI a hard requirement on every machine and CI runner
that runs the module -- a cost deliberately rejected elsewhere in this release -- and a failing destroy
provisioner halts the destroy it was meant to help. Deleting network interfaces from Terraform on a filter
is also a poor trade: if the filter is ever wrong it removes something live, and the blast radius is other
people's traffic.

**Reducing how many leak** is the better long-term answer, and it is a configuration change rather than a
cleanup. `ENABLE_PREFIX_DELEGATION` on the VPC CNI addon assigns each interface a /28 prefix instead of
individual addresses, so one interface serves many more pods and a node needs far fewer of them. Fewer
interfaces means proportionally fewer orphans, and better pod density on the same instance types. It
changes max-pods arithmetic, so it wants its own testing rather than being switched on alongside everything
else here.

---

## Destroying a cluster

A destroy that fails on a security group is almost never about the security group.

Terraform owns what it created: the VPC, subnets, security groups, the cluster, the node groups. It does
**not** own what controllers inside the cluster created on its behalf -- the ALBs and ENIs from the load
balancer controller, the EC2 instances from Karpenter, volumes from the EBS CSI driver, records from
external-dns. There is no edge in the graph to any of them, so nothing can be ordered against them.

**The usual cause is not a race at all.** The VPC CNI allocates secondary network interfaces on each node
to hand out pod IPs. When a node terminates before the CNI detaches them -- which is every Karpenter
consolidation, every spot reclaim and every node group replacement -- those interfaces are left behind in
`available` state, attached to nothing. **Nothing ever reclaims them.** AWS does not garbage-collect an
available interface, so they hold the node security group indefinitely, and `terraform destroy` fails on it
with `DependencyViolation` fifteen minutes after the thing that actually caused it.

This was observed on a teardown where four such interfaces remained, one per Karpenter node, with no load
balancer anywhere in the account. Waiting does not help, because there is nothing left running that would
ever clean them up.

There is a second, genuinely racy cause: terraform deletes an Ingress, the load balancer controller starts
deleting the ALB, and terraform -- seeing no dependency -- removes the controller mid-job, orphaning the
load balancer and its interfaces. That one is real but rarer, and it is what the module's destroy-time
delays address.

The module holds the load balancer controller alive for 30 seconds on destroy, and the Karpenter controller
for 60 -- the first is waiting on API calls, the second on pod drains. **That helps and is not enough.** It
only applies where terraform owns the Ingress objects, and a fixed wait cannot know whether AWS finished
releasing the ENIs, which happens asynchronously after the controller's work is done. A destroy has been
observed failing on the node security group with the sleeps in place.

**Run the preparation script:**

```bash
./scripts/eks-destroy-prep.sh && terraform destroy
```

Add `--delete-orphan-enis` to have it remove the detached CNI interfaces as well. That is deliberately
opt-in and deliberately narrow: an interface is removed only if its description marks it CNI-created, it is
`available`, and it has no attachment. One belonging to a load balancer, or still attached to anything, is
left alone -- there the interface is a symptom and deleting it would hide the real owner.

It deletes the objects that own AWS resources, then polls until those AWS resources are actually gone
rather than sleeping a guessed interval, and exits non-zero while anything is still holding on -- so the
`&&` stops you starting a destroy that will fail fifteen minutes later. `--dry-run` changes nothing.

**If you would rather not have a script delete things**, that is a reasonable position and the diagnosis
half stands alone:

```bash
./scripts/eks-destroy-prep.sh --check-only
```

Read-only. It reports what is holding the cluster security groups and nothing else, so it is equally useful
*after* a destroy has already failed -- which is when you most want it, and when deleting the workload
objects is no longer the question.

Its last section is what saves the most time: every ENI still attached to a cluster security group, **with
its description**. The description names the owner and the owner determines the fix. Without it you get
`DependencyViolation` on a security group that is not the problem and no indication of what is.

**The equivalent by hand:**

```bash
# 1. remove the objects that own cloud resources
kubectl delete ingress --all --all-namespaces
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer

# 2. let karpenter terminate its own instances
kubectl delete nodepool --all
kubectl get nodeclaims          # wait until this is empty

# 3. confirm the cloud resources are actually gone, not just the objects
aws elbv2 describe-load-balancers --region <region> \
  --query 'LoadBalancers[?contains(LoadBalancerName,`k8s-`)].LoadBalancerName' --output text

# 4. only now
terraform destroy
```

If a destroy has already wedged on a security group, find what still references it and remove that first:

```bash
aws ec2 describe-network-interfaces --region <region> \
  --filters "Name=group-id,Values=<sg-id>" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Desc:Description,Attach:Attachment.AttachmentId}' \
  --output table
```

The description names the owner. `ELB app/k8s-...` is an orphaned load balancer: delete it and its ENIs go
with it. `aws-K8S-i-...` is a CNI interface from a node that no longer exists: detach with `--force`, then
delete. Re-run the destroy afterwards.

Note that external-dns runs `upsert-only` by default, so Route53 records survive a teardown by design. They
do not block anything; clean them up separately if the zone matters.

---

## Quick reference: symptom to cause

Check numbers refer to `./scripts/eks-assess.sh` sections.

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Node stuck `Deleting` / drain never finishes | A PDB permitting zero evictions | E1 |
| Node group upgrade fails on pod eviction | Same | E1 |
| 502/504 burst during node replacement | No PDB, or `preStop` too short | E2, guide 3.3 |
| Service drops to zero replicas briefly | No PDB on a multi-replica service | E2 |
| Nodes far older than expected, stale kubelet | Always-on `nodes: "0"` plus `expireAfter: Never` | D2, D3, guide 2.2 |
| Every node replaced at once, unprompted | AMI selected by `id` from a sampled instance | D1 |
| Spot reclaim with no drain at all | Controller unavailable — OOMKilled or single replica restarting | C1, G1 |
| Second controller replica stuck Pending | Fewer than 2 managed-node-group nodes, or not in 2 zones | C3 |
| Pods pending for minutes after every disruption | Workloads with no resource requests | E6, guide 3.4 |
| Latency spikes with no application cause | Burstable instances throttling once credits are exhausted | F1 |
| Nodes exhaust CPU while memory sits idle | Instance shape wrong for the workload | F2 |
| Monitoring gaps during incidents | Metrics store or `kube-state-metrics` evicted | E4, guide 4.1 |
| Karpenter preempted under node pressure | Priority class demoted from `system-cluster-critical` | C1 |
| Name resolution breaks during a drain | CoreDNS has no PodDisruptionBudget | B1 |
| A node keeps an old AMI while others roll | A PDB or `do-not-disrupt` is correctly holding it | D4, guide 3.8 |
| Control plane upgraded, nodes still on the old kubelet | The disruption window is correctly blocking `Drifted`; it rolls when the window closes | D3, guide "Upgrading the Kubernetes version" |
| Node group upgrade fails on pod eviction | A PodDisruptionBudget permits zero evictions | E1, guide 3.2 |
| `terraform destroy` fails deleting a security group | Leaked VPC CNI interfaces from terminated nodes, holding it | G2, `eks-destroy-prep.sh --delete-orphan-enis` |
| Pods cannot schedule, subnet looks full, no kubernetes explanation | Leaked CNI interfaces holding IPs for nodes that no longer exist | G2 |

---

## What this guide does not cover

- Pod IP exhaustion and subnet capacity affecting node placement.
- Orphaned NodeClaims and detached volumes.
- Application-level probe and health-check tuning beyond the disruption-relevant parts.
- Upgrading the underlying `terraform-aws-modules` EKS module to v21, which is a separate migration.
