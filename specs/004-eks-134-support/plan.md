# Implementation Plan: EKS 1.34 Module Support

**Branch**: `004-eks-134-support` | **Date**: 2026-07-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-eks-134-support/spec.md`

## Summary

Move the module default Kubernetes/EKS version from 1.33 to 1.34 and align only the module-managed add-ons and Helm charts that are not already Kubernetes 1.34-compatible. Preserve existing override behavior, add explicit chart/version escape hatches for risky upgrades, and document a staged no-downtime delivery path in the top `main.tf` terraform-docs comment so `README.md` is regenerated with the upgrade guidance.

## Technical Context

**Language/Version**: Terraform `~> 1.3` module code, HCL, Helm chart values YAML  
**Primary Dependencies**: `terraform-aws-modules/eks/aws` v20.x, AWS EKS managed add-ons, Helm provider, module-managed charts for Linkerd, KEDA, External Secrets, Metrics Server, ingress-nginx, kube-state-metrics  
**Storage**: N/A  
**Testing**: `terraform fmt`, `terraform init -backend=false`, `terraform validate`, `terraform-docs`, targeted Helm metadata/render checks where feasible  
**Target Platform**: Amazon EKS Kubernetes 1.34  
**Project Type**: Terraform registry module  
**Performance Goals**: N/A  
**Constraints**: Preserve wrapper-module behavior, avoid Terraform/AWS provider major upgrades, do not perform live cluster upgrades, avoid unnecessary chart upgrades, document operational risk and rollback expectations  
**Scale/Scope**: Root module plus affected add-on submodules and examples/docs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Shared Constitution Source of Truth: Pass. Local repository constitution was reviewed; this change stays repo-scoped.
- Terraform Module Workflow Skill Enforcement: Pass. `terraform-module-developer` workflow is active before edits.
- Wrapper-First Module Design and Safe Interfaces: Pass with justified interface widening. New root inputs are limited to chart version/repository pins needed for staged no-downtime upgrades.
- Evidence-First Verification: Pass. Validation commands are defined in quickstart and will be run before closeout.
- Documentation and Compatibility Discipline: Pass. `main.tf` upgrade notes and generated README updates are part of this delivery.

## Project Structure

### Documentation (this feature)

```text
specs/004-eks-134-support/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md
```

### Source Code (repository root)

```text
.
├── main.tf
├── variables.tf
├── README.md
├── modules/
│   ├── adot/
│   ├── autoscaler/
│   ├── ebs-csi/
│   ├── eks/
│   ├── external-secrets/
│   ├── keda/
│   ├── linkerd/
│   ├── metrics-server/
│   ├── nginx-ingress-controller/
│   └── s3-csi/
└── examples/
```

**Structure Decision**: Update root defaults and affected submodule defaults in place. Add root pass-through inputs only where consumers need explicit staged-upgrade pins. Keep docs generated from terraform-docs markers.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Root-level chart version and Linkerd chart repository fields | Existing production users need controlled rollout and pinning for high-risk chart upgrades | Forcing submodule defaults without root pins would remove the ability to adopt this module release separately from production tooling rollouts |
