# Phase 0 Research: Karpenter System Isolation

## Decision 1: Keep Karpenter replica baseline at two by default

- **Decision**: Treat two replicas as the default target for Karpenter controller
  availability and verify this in module/example validation.
- **Rationale**: The feature intent confirms multi-replica behavior is already expected and
  required for resilience during single-pod failure.
- **Alternatives considered**:
  - Keep single replica default and document recommendation only (rejected: weaker
    reliability baseline).
  - Force hard-coded replicas that cannot be overridden (rejected: unnecessary rigidity).

## Decision 2: Use predefined highest priority class for Karpenter pods

- **Decision**: Bind Karpenter pods to the highest predefined priority class created by the
  priority-class module, with deterministic mapping in module defaults.
- **Rationale**: Protects autoscaling control availability under resource pressure and
  aligns with requested behavior.
- **Alternatives considered**:
  - User-provided arbitrary priority class only (rejected: too weak as default safety).
  - No explicit priority class (rejected: may allow preemption by less critical pods).

## Decision 3: Enforce system-node isolation as default behavior

- **Decision**: Keep dedicated system node scheduling boundaries so non-critical workloads
  cannot land on system nodes unless explicitly allowed.
- **Rationale**: Preserves system capacity and prevents cluster-management instability from
  application pod contention.
- **Alternatives considered**:
  - Soft recommendation in docs only (rejected: not enforceable).
  - Global hard taints with no escape hatch (rejected: may block valid operator workflows).

## Decision 4: Preserve wrapper-module interface shape

- **Decision**: Implement behavior through existing `karpenter` object inputs and example
  policy conventions; avoid broad new top-level variables unless strictly needed.
- **Rationale**: Aligns with wrapper-first discipline and reduces contract drift risk.
- **Alternatives considered**:
  - Add multiple new top-level knobs for every scheduling detail (rejected: interface
    widening and maintenance burden).

## Decision 5: Verify with example-driven checks

- **Decision**: Validation relies on terraform validation plus deployment checks from the
  `examples/eks-with-karpenter` scenario.
- **Rationale**: Existing repository testing pattern is example-focused and maps directly to
  expected scheduler outcomes.
- **Alternatives considered**:
  - Create fully new testing harness for this feature (rejected: unnecessary scope for this
    change).
