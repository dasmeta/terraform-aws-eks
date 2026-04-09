# Data Model: Karpenter System Isolation

## Entity: SystemNodeSchedulingPolicy

- **Purpose**: Defines scheduling boundaries for dedicated system nodes.
- **Fields**:
  - `node_selector_labels` (map<string,string>): labels identifying dedicated system nodes
  - `required_taints` (list<object>): taints preventing non-critical workload scheduling
  - `allowed_tolerations` (list<object>): tolerations expected for system-critical
    components only
  - `default_enforcement` (bool): whether policy applies by default
- **Validation rules**:
  - At least one identifying label or taint must be present when enforcement is enabled.
  - Non-critical workload profiles must not include allowed tolerations by default.

## Entity: WorkloadCriticalityProfile

- **Purpose**: Classifies workloads to drive scheduling and priority behavior.
- **Fields**:
  - `name` (string): workload class name (`system-critical`, `non-critical`)
  - `priority_class_name` (string): priority class binding for this class
  - `system_node_eligible` (bool): whether workload can run on system nodes
- **Validation rules**:
  - `system-critical` class must map to highest priority class.
  - `non-critical` class must have `system_node_eligible=false` by default.

## Entity: KarpenterControllerProfile

- **Purpose**: Represents scheduling and availability expectations for Karpenter.
- **Fields**:
  - `replicas` (number): desired controller replica count (default >=2)
  - `priority_class_name` (string): highest predefined class for Karpenter
  - `namespace` (string): Karpenter namespace
  - `resource_requests` (object): baseline cpu/memory requests
  - `resource_limits` (object): baseline cpu/memory limits
- **Validation rules**:
  - `replicas` must be >=2 in default profile.
  - `priority_class_name` must match highest predefined class.

## Entity: PriorityClassCatalog

- **Purpose**: Captures predefined classes available from the priority-class submodule.
- **Fields**:
  - `classes` (list<object>): class entries with `name` and numeric `value`
  - `highest_class` (object): computed class with greatest numeric priority
- **Validation rules**:
  - Catalog must include at least one class for Karpenter binding.
  - If catalog is missing, planning requires explicit fallback policy.

## Relationships

- `KarpenterControllerProfile.priority_class_name` references
  `PriorityClassCatalog.highest_class.name`.
- `WorkloadCriticalityProfile.system-critical` uses
  `SystemNodeSchedulingPolicy.allowed_tolerations`.
- `WorkloadCriticalityProfile.non-critical` is constrained by
  `SystemNodeSchedulingPolicy.required_taints`.
