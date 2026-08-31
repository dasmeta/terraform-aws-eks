# Feature Specification: Karpenter Stability Baseline

**Feature Branch**: `009-karpenter-stability-baseline`
**Created**: 2026-08-31
**Status**: Draft
**Input**: User description: "Karpenter stability baseline for dasmeta/terraform-aws-eks (DMVP-10430, case group A). Extend the existing opinionated Karpenter wrapper module so spot capacity and consolidation remain available without causing service disruption."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The node autoscaler stays up when it is needed most (Priority: P1)

As a platform operator, I want the component that reacts to reclaimed capacity to remain running and responsive during exactly the events it exists to handle, so that reclaimed nodes are drained instead of killed abruptly.

**Why this priority**: This is the direct cause of the originating incident. When the autoscaler is unavailable, reclamation warnings go unread and every reclaimed node becomes an abrupt kill regardless of any other setting. No other improvement in this feature compensates for it.

**Independent Test**: Inspect a deployed cluster and confirm the controller's resource allocation and scheduling priority match the values validated in production, and that no configuration caps its processing capacity during a scale event.

**Acceptance Scenarios**:

1. **Given** a cluster under heavy scale-up, **When** the controller processes a large batch of pending workloads, **Then** it is neither terminated for exceeding its memory allocation nor slowed by an artificial processing cap.
2. **Given** a cluster under node pressure, **When** the scheduler must choose pods to preempt, **Then** the controller ranks alongside genuinely cluster-critical components rather than below them.
3. **Given** the module is deployed with no explicit resource configuration, **When** the controller starts, **Then** it receives the allocation already validated in production rather than the values known to cause termination.
4. **Given** an operator needs different values, **When** they supply their own, **Then** those are used without editing the module.

---

### User Story 2 - Capacity changes happen on purpose, not by accident (Priority: P1)

As a platform operator, I want node replacement to occur only when something I control has actually changed, so that an unrelated infrastructure change cannot trigger a fleet-wide node replacement.

**Why this priority**: Equal to Story 1. Today an unrelated apply can silently change which machine image the fleet targets, marking every node as out-of-date at once. This produces mass node replacement with no corresponding intent, and it is the documented but unexplained "two waves of interruption" already recorded in the module's own upgrade notes.

**Independent Test**: Run the planning step repeatedly, including after node turnover, and confirm the planned machine image never changes on its own.

**Acceptance Scenarios**:

1. **Given** an unchanged configuration, **When** planning runs repeatedly, **Then** the resulting machine image selection is identical every time.
2. **Given** cluster nodes are replaced for unrelated reasons, **When** planning runs again, **Then** the machine image selection does not change.
3. **Given** an operator deliberately changes the target image, **When** the change is applied, **Then** node replacement proceeds within the configured disruption limits and time window rather than all at once.

---

### User Story 3 - Voluntary disruption is confined to safe hours (Priority: P2)

As a service owner, I want cost-driven node consolidation to avoid my busiest hours, so that optimisation never competes with serving traffic.

**Why this priority**: Repeatedly implicated across the incident review, but it reduces the frequency of harm rather than the possibility. Stories 1 and 2 must land first.

**Independent Test**: Configure a protected window covering the current time, make the cluster a candidate for consolidation, and confirm no voluntary replacement occurs until the window ends.

**Acceptance Scenarios**:

1. **Given** a protected window is active, **When** nodes become consolidation candidates, **Then** no voluntary replacement occurs for reasons of under-use or being out-of-date.
2. **Given** a protected window is active, **When** a node becomes completely empty, **Then** it may still be removed, because removing an empty node disrupts nothing.
3. **Given** the protected window has ended, **When** consolidation candidates remain, **Then** consolidation resumes automatically.
4. **Given** capacity is reclaimed by the cloud provider during a protected window, **When** the reclamation notice arrives, **Then** it is acted upon immediately, because involuntary reclamation is not something a window can defer.

---

### User Story 4 - Workloads that must not move have somewhere to run (Priority: P2)

As a platform operator, I want a way to place ingress, monitoring, and single-instance workloads on capacity that is not subject to reclamation, without hand-building node configuration per cluster.

**Why this priority**: Addresses a repeated pattern where reclaimed capacity took down ingress or monitoring and made every other incident harder to diagnose. Valuable but opt-in, so it does not gate the P1 work.

**Independent Test**: Enable the protected capacity option, place a workload on it, and confirm the workload is not scheduled onto reclaimable capacity while ordinary workloads never land on the protected capacity.

**Acceptance Scenarios**:

1. **Given** protected capacity is enabled, **When** a workload opts into it, **Then** it runs on capacity not subject to provider reclamation.
2. **Given** protected capacity is enabled, **When** an ordinary workload is scheduled, **Then** it does not land on the protected capacity.
3. **Given** protected capacity is not enabled, **When** the module is applied, **Then** no additional capacity is created and no cost is incurred.

---

### User Story 5 - Reduced exposure to reclamation (Priority: P3)

As a platform operator, I want the pool of acceptable machine types to be wide enough that reclamation is less likely and replacement capacity is easier to find.

**Why this priority**: A meaningful reduction in how often the harmful events occur, but it changes likelihood rather than consequence.

**Independent Test**: Compare the number of machine types the configuration accepts before and after, and confirm it is comfortably above the provider's recommended diversification threshold.

**Acceptance Scenarios**:

1. **Given** default configuration, **When** capacity is requested, **Then** the number of acceptable machine types is above the recommended diversification threshold.
2. **Given** an operator has narrowed the acceptable types, **When** the module is applied, **Then** their narrower choice is respected.

---

### Edge Cases

- **A cluster too small to run two controller instances**: the controller's placement rules require two separate nodes in two separate availability zones. A cluster not meeting that shape leaves the second instance permanently unscheduled. This must be visible to the operator rather than silently accepted.
- **A single-zone cluster**: same as above; the shape can never be satisfied, so a single instance is the honest configuration.
- **Protected window covering all hours**: voluntary consolidation would never run and out-of-date nodes would never be replaced. Configuration must remain possible but the consequence must be documented.
- **Protected windows in non-European regions**: schedules are interpreted in coordinated universal time only, so the default window is wrong for other regions and drifts by an hour under daylight saving. Operators must be able to override it.
- **A workload that refuses to terminate**: without an upper bound on drain time, a single such workload keeps a node in a terminating state indefinitely and blocks the capacity change entirely.
- **Existing clusters upgrading to these defaults**: the change alters live behaviour. It must not require manual state manipulation, and every behavioural change must be documented before it is applied.
- **Deliberate machine image change**: replacing every node is correct here, but must be paced by the disruption limits rather than happening simultaneously.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The autoscaling controller MUST receive a resource allocation matching the values already validated in production, and MUST NOT be configured with a processing cap that throttles it during a scale event.
- **FR-002**: The controller's resource allocation MUST be overridable by operators without modifying the module.
- **FR-003**: The controller MUST be assigned a scheduling priority equivalent to other cluster-critical components, and MUST NOT be demoted below them by default.
- **FR-004**: Machine image selection MUST be deterministic: identical configuration MUST produce an identical selection on every planning run, regardless of which nodes are currently running.
- **FR-005**: Machine image selection MUST be expressible by operators, so that a deliberate change is an explicit act.
- **FR-006**: The module MUST grant the permissions required by the upgraded autoscaler version for its capacity-health checks, without upgrading the underlying upstream module.
- **FR-007**: When the cluster cannot satisfy the controller's placement requirements for the requested number of instances, the module MUST surface this rather than leaving an instance silently unscheduled.
- **FR-008**: Node pools MUST support an upper bound on how long a node may take to drain, so a single uncooperative workload cannot block a capacity change indefinitely.
- **FR-009**: Node pools MUST support restricting voluntary disruption to configurable time windows, selectable by disruption reason.
- **FR-010**: A default protected window MUST be applied covering ordinary European business hours, blocking disruption caused by under-use and by being out-of-date, while continuing to permit removal of empty nodes.
- **FR-011**: The protected window MUST be overridable and MUST be documented as interpreted in coordinated universal time, including the consequence for other regions and for daylight saving transitions.
- **FR-012**: Voluntary consolidation MUST default to a policy that weighs cost saving against disruption, and MUST wait materially longer than the current setting before acting.
- **FR-013**: The default set of acceptable machine types MUST be wide enough to exceed the provider's recommended diversification threshold, while remaining overridable.
- **FR-014**: Node age-based replacement MUST have a deliberate, documented default rather than being disabled indefinitely.
- **FR-015**: The module MUST offer optional protected capacity, not subject to provider reclamation, which ordinary workloads do not land on and which incurs no cost when not enabled.
- **FR-016**: The autoscaler MUST be upgraded to the current supported version, including its separately-managed definitions, with any manual upgrade steps documented.
- **FR-017**: The node configuration package MUST be updated to its current published version.
- **FR-018**: The consumer interface MUST remain minimal and grouped, every grouped and nested field MUST carry an inline description, and no existing input MUST change between required and optional.
- **FR-019**: Applying the new defaults MUST NOT require manual state manipulation.
- **FR-020**: Every behavioural change MUST be documented in the module's upgrade guidance in the same delivery, including what changes without action, and what an operator must decide.
- **FR-021**: Pre-provisioned spare capacity MUST be evaluated against the upgraded autoscaler's capability, with a documented decision to adopt or defer and the reasoning recorded.

### Key Entities

- **Effective controller allocation**: the processing and memory resources granted to the autoscaling controller. Too small causes termination under load; a processing cap causes throttling during exactly the events that matter.
- **Machine image selection**: the declaration of which image new nodes are built from. Must be a stable function of configuration alone.
- **Disruption window**: a recurring period during which voluntary node replacement is suppressed, selectable by reason. Never applies to provider-initiated reclamation.
- **Protected capacity**: node capacity not subject to provider reclamation, reserved by opt-in for workloads that cannot tolerate being moved.
- **Controller placement shape**: the cluster topology required for the requested number of controller instances to schedule, expressed as separate nodes across separate availability zones.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The autoscaling controller survives a full scale-up without being terminated for resource exhaustion, and without being throttled.
- **SC-002**: The controller is never selected for preemption ahead of other cluster-critical components.
- **SC-003**: Repeated planning runs over unchanged configuration produce byte-identical machine image selection, including after node turnover.
- **SC-004**: No node replacement occurs that does not correspond to an operator-initiated change or a provider-initiated reclamation.
- **SC-005**: During a protected window, no voluntary node replacement occurs for under-use or out-of-date reasons, while empty-node removal and provider reclamation continue unaffected.
- **SC-006**: A cluster that cannot host the requested number of controller instances reports this at planning or through an explicit status, and never leaves an instance silently unscheduled.
- **SC-007**: The number of acceptable machine types under default configuration exceeds the provider's recommended diversification threshold.
- **SC-008**: A node drain completes within the configured upper bound even when a workload resists termination.
- **SC-009**: Both reference examples apply successfully and demonstrate the new behaviour, one with the defaults and one with protected capacity enabled.
- **SC-010**: Upgrading an existing deployment requires no manual state manipulation, and every behavioural change is documented before it takes effect.

## Assumptions

- Shipping improved defaults rather than opt-in flags is correct, and was explicitly directed. The alternative leaves every existing deployment exposed until individually retuned, which the incident review shows repeatedly does not happen.
- Dropping the processing cap on the controller rather than raising it is correct. A cap throttles the controller during precisely the scale events it must react to. This diverges from a per-deployment hotfix that raised the cap instead, and is called out for operator confirmation.
- A European business-hours default window is appropriate for the majority of current deployments and wrong for others by design. Documented override is the mitigation.
- The default is more conservative than current behaviour and will reduce consolidation frequency, therefore increasing spend. This is the intended trade.
- Age-based node replacement interacts with disruption windows: replacement is deferred into the permitted window rather than suppressed.

## Out of Scope

- Upgrading the underlying upstream autoscaler infrastructure module to its next major version. It removes inputs this module currently supplies, changes the identity mechanism, and requires state migration. Tracked separately so an identity migration is not bundled with an incident fix.
- Workload-side protection such as disruption budgets, replica spread, and shutdown timing. Delivered separately in the shared application chart.
- Per-deployment retuning of node pools.
- Network capacity and address-exhaustion review affecting node placement.
- Cleanup of orphaned node records and detached storage.
- Alerting implementation. This feature defines what should be observable; building the alerts is separate.
