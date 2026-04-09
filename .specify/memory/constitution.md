<!--
Sync Impact Report
- Version change: template-placeholder -> 1.0.0
- Modified principles:
  - Added: I. Shared Constitution Source of Truth
  - Added: II. Terraform Module Workflow Skill Enforcement
  - Added: III. Wrapper-First Module Design and Safe Interfaces
  - Added: IV. Evidence-First Verification
  - Added: V. Documentation and Compatibility Discipline
- Added sections:
  - Operational Constraints
  - Delivery Workflow and Quality Gates
- Removed sections: None
- Templates requiring updates:
  - ✅ checked (no change needed): .specify/templates/plan-template.md
  - ✅ checked (no change needed): .specify/templates/spec-template.md
  - ✅ checked (no change needed): .specify/templates/tasks-template.md
  - ⚠ pending: .specify/templates/commands/*.md (directory not present in this repository)
- Follow-up TODOs: None
-->

# Dasmeta Terraform AWS EKS Constitution

## Core Principles

### I. Shared Constitution Source of Truth
This repository MUST treat `~/.codex/constitution/.specify/memory/constitution.md`
as the authoritative source for cross-repository governance. Local rules in this
repository MAY add repository-specific constraints, but MUST NOT conflict with shared
constitution governance. If any conflict is detected, work MUST stop and the conflict
MUST be surfaced explicitly before implementation.
Rationale: prevents fragmented standards and inconsistent behavior across repositories.

### II. Terraform Module Workflow Skill Enforcement
Any task that creates, extends, standardizes, or restructures Terraform modules in this
repository MUST follow the `terraform-module-developer` skill guidance before edits are
applied. The workflow MUST include repository-scope inspection, wrapper-module bias,
approval gates for interface widening and breaking changes, and constitution-source
alignment checks.
Rationale: enforces consistent module quality and avoids unsafe, ad hoc module changes.

### III. Wrapper-First Module Design and Safe Interfaces
When adding capabilities, contributors MUST prefer opinionated wrapper patterns over
broad upstream pass-through interfaces. Input surfaces MUST remain minimal and stable.
Grouped object inputs MAY be used only when required/optional semantics remain stable.
If a change widens the interface or alters requiredness semantics, explicit approval
MUST be obtained before implementation.
Rationale: protects consumers from unnecessary complexity and contract drift.

### IV. Evidence-First Verification
Contributors MUST validate behavior with reproducible evidence before claiming success.
For module changes, verification MUST include at least relevant formatting/validation,
documentation sync where applicable, and targeted tests or example-based checks when
available. If any verification step cannot run, the limitation and risk MUST be stated.
Rationale: keeps outcomes reviewable and reduces hidden regressions.

### V. Documentation and Compatibility Discipline
Changes that affect module behavior, inputs, outputs, versions, or upgrade paths MUST
be reflected in repository documentation in the same delivery scope. Backward-incompatible
changes MUST include migration guidance and require explicit approval before release.
Compatibility-sensitive updates MUST call out operational risk and rollback expectations.
Rationale: keeps adopters safe during upgrades and makes operational impacts explicit.

## Operational Constraints

- This repository MUST remain Terraform module focused; unrelated tooling changes are out
  of scope unless explicitly requested.
- Naming and examples MUST avoid customer-identifying values and use neutral or dasmeta
  context naming.
- Local repository guidance MUST stay repository-specific and avoid duplicating shared
  cross-repository governance text when a reference to the shared constitution is enough.

## Delivery Workflow and Quality Gates

- Plan and execution artifacts MUST include a constitution check aligned with these
  principles and shared constitution governance.
- Proposed breaking changes, standards conflicts, governance-source conflicts, and scope
  expansion outside this repository MUST be raised as approval gates before editing.
- Delivery MUST update implementation, tests/examples, and docs together when applicable.

## Governance

This constitution governs contributor behavior for this repository and is subordinate to
the shared governance source at `~/.codex/constitution/.specify/memory/constitution.md`
for cross-repository standards.

Amendments require:

- documented reason for the change
- explicit assessment of shared-constitution alignment
- update of impacted templates or documentation artifacts in the same change
- semver versioning of this constitution according to governance impact:
  - MAJOR: incompatible removals or redefinitions of principles
  - MINOR: new principle/section or materially expanded mandatory guidance
  - PATCH: clarifications and non-semantic wording improvements

Compliance review expectations:

- every plan, spec, and task set derived from this repository MUST pass constitution checks
- unresolved governance conflicts MUST block implementation
- deviations MUST be documented in writing with justification and approval

**Version**: 1.0.0 | **Ratified**: 2026-04-08 | **Last Amended**: 2026-04-08
