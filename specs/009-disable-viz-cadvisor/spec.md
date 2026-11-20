# Feature Specification: Disable Linkerd Viz cAdvisor collection

Created: 2026-10-19. Status: implementation requested.

## User Scenarios & Testing

### US1 — Remove duplicate container collection (P1)
An operator disables only Linkerd Viz's cluster-wide cAdvisor scrape while
retaining its controller, proxy and self-monitoring jobs. The main collector
continues providing container metrics. The requested first consumer is dev.

Acceptance: opting out removes exactly one scrape job and changes no other
rendered resource or configuration. An ordinary Helm reconciliation retains
the opt-out. Unrecognized chart layouts fail visibly rather than silently
restoring the job.

### US2 — Preserve existing consumers (P1)
Omitting the new option preserves the upstream chart unchanged. Disabling Viz
entirely remains supported.

## Requirements
- FR1: expose an optional, default-enabled cAdvisor collection setting.
- FR2: remove the built-in job before Helm applies the chart, not by a second
  owner patching Helm's ConfigMap after apply.
- FR3: preserve all unrelated chart values and objects.
- FR4: do not deploy production or change existing version pins silently.

## Success Criteria
- Default render unchanged; opt-out render contains all other jobs unchanged.
- Native Terraform tests verify both default and opt-out release configuration.
- Official pinned chart render passes a semantic comparison and promtool.

## Assumptions and Edge Cases
The pinned chart has no native job opt-out. Its `scrapeConfigs` appends jobs;
its `metricRelabelConfigs` only affects proxy metrics. Empty/disabled Viz charts
must not require the job to exist. Unsupported enabled-chart layout must fail.
