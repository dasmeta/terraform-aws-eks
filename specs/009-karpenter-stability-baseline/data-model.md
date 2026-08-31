# Phase 1 Data Model: Karpenter Stability Baseline

**Feature**: `specs/009-karpenter-stability-baseline` | **Date**: 2026-08-31

No persisted data. These are configuration entities resolved at plan time.

## Entity: Controller allocation

| Attribute | Default | Notes |
| --- | --- | --- |
| `requests.cpu` | `250m` | Value validated in production |
| `requests.memory` | `512Mi` | Value validated in production |
| `limits.memory` | `1Gi` | Bounds node-level risk |
| `limits.cpu` | **absent** | Deliberately unset; a cap throttles the controller during the events it must react to |

**Validation**: a CPU limit may be supplied by an operator who wants one, but the module never sets one by default.

## Entity: Machine image selection

| Attribute | Derivation | Notes |
| --- | --- | --- |
| alias family | from declared node group `ami_type` | `AL2023_*`→`al2023`, `AL2_*`→`al2`, `BOTTLEROCKET_*`→`bottlerocket` |
| alias version | `latest` | Overridable to a pinned `vYYYYMMDD` |
| full selector | operator override | Escape hatch when alias is insufficient |

**Validation**: must be a pure function of configuration. No data source may sample running infrastructure.

**State transition**: changing the alias version, or a new AMI release when on `latest`, marks nodes drifted. Drift is paced by disruption budgets and suppressed during protected windows.

## Entity: Disruption window

| Attribute | Type | Default |
| --- | --- | --- |
| `schedule` | cron string, UTC only | `0 6 * * mon-fri` |
| `duration` | compound duration | `12h` |
| `reasons` | list | `["Drifted", "Underutilized"]` |
| `nodes` | count or percentage | `"0"` during the window |

**Validation rules**

- Schedules are interpreted in UTC. No timezone field exists upstream.
- `schedule` and `duration` must be set together or both omitted.
- Multiple budgets resolve most-restrictive-wins.
- Applies to voluntary disruption only. Never delays provider reclamation, and never delays expiry.

## Entity: Drain ceiling

| Attribute | Default | Notes |
| --- | --- | --- |
| `terminationGracePeriod` | `24h` | Deliberately long: a stuck-node safety net, not a shutdown budget |

**Validation**: once it expires, remaining pods are deleted regardless of disruption budgets. A short value therefore becomes a source of disruption rather than a protection against it.

## Entity: Protected capacity

| Attribute | Default | Notes |
| --- | --- | --- |
| `enabled` | `false` | On-demand capacity has real cost |
| capacity type | on-demand only | Not subject to provider reclamation |
| taint | `NoSchedule` | Ordinary workloads never land here |
| consolidation | `WhenEmpty` | Only genuinely empty nodes are removed |

## Entity: Controller placement shape

The cluster topology required for the requested controller replica count to schedule.

| Requirement | Source | Enforced? |
| --- | --- | --- |
| replicas <= 1, or at least 2 subnets | module input | **Yes** — plan-time precondition |
| at least 2 non-Karpenter nodes | managed node group | No — not knowable at plan time; documented with diagnostics |
| those nodes in >= 2 availability zones | managed node group | No — same |

The split is deliberate: fail on what is provable, document what is not, and never leave an unsatisfiable request silently Pending.
