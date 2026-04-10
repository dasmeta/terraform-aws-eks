# Contract: Karpenter System Scheduling

## Goal

Define enforceable behavior for Karpenter priority, replica baseline, and dedicated system
node isolation in the EKS module.

## Inputs and Behavior Contract

### C-001: System node isolation default

- Dedicated system nodes MUST reject non-critical workloads by default.
- Non-critical workloads without explicit system-node eligibility MUST schedule on
  general worker pools.

### C-002: Karpenter priority class

- Karpenter controller pods MUST use the highest predefined priority class from the
  priority-class catalog.
- If the expected class is absent, module behavior MUST fail fast with clear error or use
  a documented deterministic fallback path.

### C-003: Karpenter replica baseline

- With default module settings, Karpenter controller replicas MUST be at least two.
- User overrides MAY increase replicas; reducing below two SHOULD require explicit
  opt-out semantics and documentation warning.

### C-004: Compatibility

- Existing consumers using default settings MUST keep equivalent or safer behavior after
  this feature.
- Any interface-breaking drift (renamed required keys, requiredness changes) is out of
  scope without explicit approval.

## Verification Contract

### V-001: Scheduling verification

- Deploy at least one non-critical workload in the example scenario.
- Confirm it does not schedule on dedicated system nodes.

### V-002: Priority verification

- Inspect Karpenter pods and confirm the effective priority class is the highest predefined
  class.

### V-003: Replica verification

- Confirm at least two Karpenter pods are running in healthy state by default.
- Simulate one-pod unavailability and confirm autoscaling control remains available.
