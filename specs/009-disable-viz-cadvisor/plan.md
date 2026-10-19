# Plan: Disable Linkerd Viz cAdvisor collection

User authorization: disable duplicate cAdvisor collection in dev first, then
provide code. Scope is the existing EKS Linkerd wrapper and child module.

## Current state and design
Initially checked against v2.27.0, matching dev; rebased onto current main for the PR. The chart 2025.10.7 hardcodes the job. Preserve
the wrapper and add one optional boolean in its existing grouped Linkerd
input. A conditional Helm post-renderer removes the single cAdvisor block
from the known ConfigMap. It uses POSIX sh/awk already available in the Linux
Terraform runner; no Python/YAML installation or cluster access is required.
The renderer buffers output and fails closed on unexpected chart structure.
No provider floor or default behavior changes. No new module or public-module
fallback. No general-purpose postrenderer API.

## Constitution and standards check
Use `.specify/memory/constitution.md` and
`~/.codex/constitution/.specify/memory/constitution.md`. The requested opt-out
is additive, optional and default-preserving. No requiredness changes or
unrelated governance changes. Speckit package includes spec, plan, tasks
before module edits. Clarification skipped: scope and environment were supplied.
Modern capability: supported, Helm provider 2.x postrender block; chart source
is official https://helm.linkerd.io/edge/linkerd-viz-2025.10.7.tgz.
Existing baseline includes examples, native child tests, pre-commit and CI;
root testing of all AWS infrastructure is outside this bounded change.
CloudBrowser cAdvisor documentation search returned no match. Implementation
specs remain source-controlled engineering artifacts; no operational hypothesis
is persisted as a confirmed CloudBrowser cause.

## Files and validation
Update root main.tf/variables.tf, child main.tf/variables.tf, a bounded renderer,
native tests, examples and README. Test against the actual chart and compare
all YAML documents semantically; only the one scrape job may differ.
Run native Terraform tests, fmt, validate, shell syntax, invalid-input checks.

## Delivery and rollback
Prepare module source and a consumer example. Do not invent a released version
or activate an option against a module version that ignores it. A module
release and a dev pin update are prerequisites to durable IaC rollout.
Existing live dev test remains separate; production is unchanged. Rollback:
restore the default option in a reviewed plan, recognizing duplicate collection
and memory risk returns. Existing MR !181 is not modified by this work.
