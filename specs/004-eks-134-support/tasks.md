# Tasks: EKS 1.34 Module Support

**Input**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md)

## Phase 1: Research And Safety Gates

- [x] T001 Review repository constitution and Terraform module workflow requirements
- [x] T002 Gather EKS 1.34 support dates, release notes, and Kubernetes API migration references
- [x] T003 Check current module defaults and module-owned Kubernetes manifests for stale versions and deprecated APIs
- [x] T004 Identify Linkerd production migration risk and required staged rollout guidance

## Phase 2: Implementation

- [x] T005 Change root and submodule EKS defaults from `1.33` to `1.34`
- [x] T006 Update Cluster Autoscaler default image patch to `3`
- [x] T007 Update only KEDA, External Secrets, Metrics Server, ingress-nginx, kube-state-metrics, and Linkerd defaults required for EKS 1.34 support
- [x] T008 Add root-level chart version/repository overrides needed for staged upgrades
- [x] T009 Update External Secrets examples from `external-secrets.io/v1beta1` to `external-secrets.io/v1`
- [x] T010 Add EKS 1.34 migration/changelog notes and staged no-downtime rollout guidance to the top `main.tf` terraform-docs comment

## Phase 3: Documentation And Validation

- [x] T011 Regenerate root and affected module READMEs with terraform-docs
- [x] T012 Run Terraform formatting and validation
- [x] T013 Run targeted Helm metadata/render checks where feasible
- [x] T014 Run stale-version/API scan and review expected historical upgrade-note hits only
- [x] T015 Update Jira with implementation evidence and residual rollout risks
