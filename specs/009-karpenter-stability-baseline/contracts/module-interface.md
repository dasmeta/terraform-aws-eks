# Module Interface Contract

**Feature**: `specs/009-karpenter-stability-baseline`

New and changed consumer inputs. All additions are optional attributes on the existing grouped `karpenter` object, so no consumer is required to change anything on upgrade.

## New attributes under `karpenter`

| Input | Type | Default | Purpose |
| --- | --- | --- | --- |
| `controller_resources` | object, all optional | requests `250m`/`512Mi`, memory limit `1Gi`, no CPU limit | Size the controller. Raise memory on large clusters |
| `disruption_windows` | list of objects, optional | 06:00-18:00 UTC Mon-Fri blocking `Drifted` and `Underutilized` | Suppress voluntary consolidation during business hours |
| `termination_grace_period` | string | `24h` | Upper bound on drain before remaining pods are removed |
| `protected_node_pool` | object, all optional | `enabled = false` | Opt-in on-demand capacity for workloads that must not move |
| `ami_alias` | string | derived from node group `ami_type`, version `latest` | Declarative image selection; pin to stop drift |

## Changed defaults

| Setting | Before | After | Consumer impact on upgrade |
| --- | --- | --- | --- |
| controller CPU limit | `200m` | none | Controller no longer throttled. No action |
| controller memory limit | `256Mi` | `1Gi` | Controller no longer OOMKilled. No action |
| controller requests | `100m`/`128Mi` | `250m`/`512Mi` | Slightly more reserved capacity per node |
| controller priority | `high` (1,000,000) | `system-cluster-critical` (2,000,000,000) | Controller stops being a preemption candidate. Pod is recreated |
| AMI selection | arbitrary running instance | `alias` from declared `ami_type` | **One-time paced node roll** if the resolved image differs |
| consolidation policy | `WhenEmptyOrUnderutilized` | `Balanced` | Less frequent consolidation, higher spend |
| `consolidateAfter` | `3m` | `15m` | Less churn |
| instance CPU range | `< 9` | `2` to `32` | Wider candidate pool, lower interruption rate |
| instance memory range | `< 33000` | `2000` to `131072` | Wider candidate pool |
| disruption budgets | `10%`, always active | `10%` plus a business-hours block | Consolidation pauses 06:00-18:00 UTC on weekdays |
| Karpenter chart | `1.9.0` | `1.14.1` | Definitions chart upgraded first; see upgrade guide |
| karpenter-nodes chart | `0.1.0` | `0.1.2` | Alignment only |

## Explicitly unchanged

| Setting | Value | Why |
| --- | --- | --- |
| `expireAfter` | `Never` | Expiry bypasses disruption budgets entirely, so a finite value would replace nodes unpaced and outside the protected window. Patching is handled by budget-paced AMI drift instead |
| GPU node class image lookup | `most_recent = true` | Same drift characteristic as the fixed default class, but opt-in and separable. Recorded as follow-up |
| capacity buffers | not adopted | Deferred; see research E12 |
| upstream eks karpenter submodule | `20.37.2` | Major upgrade tracked separately |

## Compatibility

- No input changes between required and optional.
- No manual state migration.
- A consumer who has overridden any of the changed defaults keeps their override; defaults apply only where nothing was set.
