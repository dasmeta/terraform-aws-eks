# Verification — 2026-10-19

- Before implementation the opt-out native test failed: no renderer was set.
- After implementation, child `terraform test` passes 7 tests (including the
  existing CRD and webhook tests), using Helm 2.17.0 and Terraform 1.15.7. Existing provider
  binaries were reused through `init -plugin-dir` after a network installation
  stalled. Local lockfile is ignored and not part of delivery.
- Child `terraform validate` succeeds.
- The official Linkerd Viz 2025.10.7 chart passes 4 renderer tests: complete
  semantic resource/job comparison, incorrect namespace, duplicate job, and
  unrecognized layout. Exactly one job is removed; no other object changes.
- Relevant `terraform fmt -check`, `git diff --check`, and `sh -n` pass.
- Documentation input tables regenerated without unrelated root doc changes.

Not performed: root EKS AWS plan, module publication/release, infrastructure pin
upgrade, Terraform apply, or any production mutation. The consumer example
requires a released module with this input. The earlier live dev-only patch
and successful rollout are not evidence that this source has been released.

PR preparation: rebased onto current main; all 7 native tests and 4 official-chart
renderer tests pass. The local-path/account-ID guard passes. The global
auto-documentation hook rewrites unrelated module READMEs with this local tool
version, so its changes were discarded and only that hook was skipped for the
commit. The two affected input tables were generated and checked separately.
