# Phase 0 Research: Upgrade ALB Controller

## Decision 1: Target the upstream `v3.3.0` policy and chart baseline

- **Decision**: Use the AWS load balancer controller Helm chart `3.3.0` and refresh the
  checked-in IAM policy from the upstream tagged path for `v3.3.0`.
- **Rationale**: The feature request explicitly targets that release, and upstream release
  sources show `v3.3.0` as the current baseline for this work on 2026-05-19. The local
  checked-in policy is older and lacks newer permissions present in the upstream policy.
- **Alternatives considered**:
  - Keep the current local policy and chart baseline (rejected: contradicts the request
    and risks permission drift).
  - Fetch the IAM policy dynamically during apply (rejected: weaker reproducibility and
    contrary to the repository's checked-in artifact pattern).

## Decision 2: Preserve the root wrapper and widen it only through narrow optional fields

- **Decision**: Keep `alb_load_balancer_controller` as the root consumer interface and add
  only the smallest new optional controls needed for release source, image override, and
  identity mode selection.
- **Rationale**: The local constitution and module skill both require wrapper-first
  behavior. The repository already groups ALB-controller configuration under one object,
  so extending that object is safer than adding many new top-level inputs or forwarding
  arbitrary Helm chart settings.
- **Alternatives considered**:
  - Expose many new top-level variables in the root module (rejected: interface sprawl).
  - Pass through the full upstream Helm chart surface (rejected: violates wrapper-first
    discipline and weakens supported defaults).

## Decision 3: Support three identity states, but reject conflicting dual attachment

- **Decision**: Support these valid states:
  - service-account role annotation enabled
  - built-in Pod Identity association enabled
  - neither built-in attachment mode enabled, for externally managed Pod Identity
  Reject configurations that enable both built-in attachment modes together.
- **Rationale**: The user explicitly requires the third state for separately managed Pod
  Identity associations. Allowing both built-in modes at once creates ambiguous ownership
  and makes verification less deterministic.
- **Alternatives considered**:
  - Force one mode to take precedence when both are enabled (rejected: hidden behavior and
    higher operational ambiguity).
  - Require exactly one built-in mode (rejected: conflicts with the approved external
    association use case).

## Decision 4: Direct chart package source is authoritative

- **Decision**: If a direct `.tgz` chart package endpoint is provided, treat it as the
  authoritative chart source and ignore any repository value provided alongside it.
- **Rationale**: This matches operator expectations for explicitly pinned artifacts and
  keeps source resolution deterministic.
- **Alternatives considered**:
  - Fail when both are provided (rejected: stricter than requested and less convenient for
    mirrored environments).
  - Continue to use repository values with a direct package endpoint (rejected: confusing
    and inconsistent with explicit artifact pinning).

## Decision 5: Keep the dedicated example self-contained by default

- **Decision**: Make the new `examples/eks-with-alb-controller` scenario use the
  service-account role annotation path by default.
- **Rationale**: The example is primarily for validation and documentation. The legacy
  annotation path keeps the example self-contained and avoids requiring extra external
  Pod Identity setup to prove the feature works end to end.
- **Alternatives considered**:
  - Use built-in Pod Identity association by default (rejected: introduces extra EKS
    Pod Identity prerequisites into the basic validation path).
  - Require manual external Pod Identity association in the example (rejected: too much
    setup overhead for a canonical example).

## Decision 6: Remove dead ALB log implementation, preserve compatibility-sensitive inputs

- **Decision**: Remove commented and unused ALB log helper implementation from the child
  module, including the nested `terraform-aws-alb-cloudwatch-logs-json` subdirectory, but
  treat any existing root-wrapper ALB log fields as compatibility-sensitive until their
  removal is explicitly approved.
- **Rationale**: The implementation is inactive and requested for cleanup, but deleting
  accepted root-level fields risks breaking existing callers even if those fields are
  operationally unused today.
- **Alternatives considered**:
  - Remove both the implementation and the root inputs immediately (rejected: potential
    backward-incompatible interface change).
  - Leave dead code in place for compatibility (rejected: contradicts the cleanup goal and
    keeps misleading unsupported behavior in the module).

## Decision 7: Verification should stay example-driven

- **Decision**: Validate this change through Terraform formatting/validation, documentation
  sync, and the new dedicated example rather than inventing a separate test harness.
- **Rationale**: This repository already uses example-based validation patterns, and the
  feature includes a new example specifically intended to exercise the module.
- **Alternatives considered**:
  - Add a new standalone test framework for the module (rejected: unnecessary scope).
  - Rely on docs-only verification (rejected: insufficient evidence for module behavior).
