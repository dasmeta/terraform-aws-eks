# Baseline Results

**Feature**: `specs/009-karpenter-stability-baseline` | **Captured**: 2026-08-31
**Baseline**: branch `main` (`380bd77`), module v2.29.1

Current behaviour recorded before any module edit, so the before/after contrast is evidence rather than assertion.

## T003 — Current rendered configuration

| Setting | Current value | Source |
| --- | --- | --- |
| controller requests | `100m` CPU / `128Mi` | `modules/karpenter/main.tf:110-121` |
| controller limits | `200m` CPU / `256Mi` | same, hard-coded |
| controller priority | `high` (1,000,000) | root `locals.tf:71-75` |
| `amiSelectorTerms` | `[{ id = <arbitrary running instance's AMI> }]` | `modules/karpenter/locals.tf:19-21` |
| consolidation | `WhenEmptyOrUnderutilized`, `consolidateAfter: 3m` | `modules/karpenter/variables.tf:166-172` |
| budgets | `[{ nodes: "10%" }]`, always active | same |
| `expireAfter` | `Never` | `modules/karpenter/locals.tf:52` |
| `terminationGracePeriod` | absent | not set anywhere |
| instance CPU | `> 1` and `< 9` | `modules/karpenter/variables.tf:129-145` |
| instance memory | `> 2000` and `< 33000` | same |
| Karpenter chart | `1.9.0` | `modules/karpenter/variables.tf:52` |
| karpenter-nodes chart | `0.1.0` | `modules/karpenter/variables.tf:58` |
| protected capacity | none | no such pool exists |

The controller limits are the values diagnosed in the field as causing CPU throttling and OOMKills during scale-up. They are still what a clean install receives.

## T004 — The determinism defect

`modules/karpenter/data.tf`:

```hcl
data "aws_instances" "ec2_from_eks_node_pools" {
  filter { name = "tag:karpenter.sh/discovery"  values = [var.cluster_name] }
  instance_state_names = ["running"]
}

data "aws_instance" "ec2_from_eks_node_pool" {
  instance_id = data.aws_instances.ec2_from_eks_node_pools.ids[0]
}
```

`ids` is an unordered set of currently-running instances. `ids[0]` therefore samples **live infrastructure**, not configuration. When the sampled node is replaced by one built from a different AMI, `amiSelectorTerms` changes, and every node in the fleet is marked drifted simultaneously.

This is the mechanism behind the "two separate waves of change" already recorded in the module README as unexplained.

**Why this is recorded rather than reproduced here**: making the value actually flip requires real node turnover with a differing AMI. That belongs to the live-cluster tier. What is provable statically, and asserted by the native tests, is the inverse property after the fix: the selection is a pure function of configuration, containing no reference to a data source that reads running infrastructure.

## T005 — Missing IAM permission

The vendored upstream module at `.terraform/modules/karpenter.this/modules/karpenter/policy.tf:145-153` grants `AllowRegionalReadActions`:

```
ec2:DescribeAvailabilityZones, ec2:DescribeImages, ec2:DescribeInstances,
ec2:DescribeInstanceTypeOfferings, ec2:DescribeInstanceTypes,
ec2:DescribeLaunchTemplates, ec2:DescribeSecurityGroups,
ec2:DescribeSpotPriceHistory, ec2:DescribeSubnets
```

`ec2:DescribeInstanceStatus` is **absent**. Karpenter 1.12+ requires it for the interruption controller's EC2 instance-status health checks — the capability most directly relevant to the originating incident. Upgrading the chart without granting it would leave the new code path failing with AccessDenied and the capability silently inactive.

## After-state

To be completed by T035.

## After-state (T035)

**Verified**: `terraform validate` passes; `terraform fmt -recursive -check` clean; `terraform test` **6 passed, 0 failed**; both Karpenter examples validate.

| Setting | Before (v2.29.1) | After (v2.30.0) |
| --- | --- | --- |
| controller requests | `100m` / `128Mi` | `250m` / `512Mi` |
| controller memory limit | `256Mi` | `1Gi` |
| controller cpu limit | `200m` | **removed** |
| controller priority | `high` (1,000,000) | `system-cluster-critical` (2,000,000,000) |
| AMI selection | `aws_instances...ids[0]` (samples live infra) | `alias` from declared `ami_type` |
| consolidation | `WhenEmptyOrUnderutilized` / `3m` | `Balanced` / `15m` |
| disruption windows | none | 06:00-18:00 UTC Mon-Fri, `Drifted`+`Underutilized` |
| `terminationGracePeriod` | absent | `24h` |
| instance CPU / memory | `<9` / `<33000` | `2-32` / `2000-131072` |
| protected capacity | none | opt-in tainted on-demand pool |
| `ec2:DescribeInstanceStatus` | not granted | granted |
| Karpenter chart | `1.9.0` | `1.14.1` |
| karpenter-nodes chart | `0.1.0` | `0.1.2` |
| `expireAfter` | `Never` | `Never` (deliberate, see E6) |

### Determinism (SC-003), verified statically

```sh
$ grep -c "aws_instances" modules/karpenter/*.tf
0
```

The data sources that sampled running infrastructure are gone. `amiSelectorTerms` is now `[{ alias = var.ami_alias }]` — a pure function of configuration — so repeated plans cannot select a different image without a configuration change. This is the guarantee behind SC-003 and SC-004.

**Honest limit**: this is a static guarantee, not an executed before/after comparison. Making the old value actually flip requires real node turnover with a differing AMI, which belongs to the live-cluster tier. What is asserted here is the property that makes the flip impossible.

### Native tests

Six plan-time runs, all passing with mocked providers and no AWS credentials:

| Test | Asserts |
| --- | --- |
| `two_replicas_with_one_subnet_is_refused` | the new precondition fires; previously this produced a silently Pending replica |
| `one_replica_with_one_subnet_is_allowed` | the precondition does not over-fire on a coherent request |
| `defaults_plan_with_two_subnets` | the default configuration plans cleanly |
| `pinned_ami_alias_is_accepted` | operators can pin to stop drift |
| `disruption_windows_can_be_disabled` | the UTC default can be turned off for non-EU regions |
| `protected_node_pool_can_be_enabled` | the opt-in pool plans cleanly |

Mocking required typed overrides for `aws_iam_policy_document`, `aws_partition`, `aws_region` and `aws_caller_identity`; the generic mock returns placeholder strings that the AWS provider rejects when validating policy JSON and ARNs.

**Scope limit stated plainly**: values embedding upstream module outputs (node IAM role name, interruption queue) are unknown under mocks, so assertions on the fully rendered node pool YAML are not possible without credentials. Those belong to the live tiers.

### Defect found while implementing

Both Karpenter examples carried `resource_configs_defaults.limits` at the top level, where the submodule expects it under `.default`.

The first assessment of this was wrong. It was assumed the mis-nesting would fail at plan time. It does not. Terraform's object type conversion **silently drops** attributes the target type does not declare, so the top-level `limits` was discarded on the way into the submodule and the node pools fell back to the module default of `cpu = 1000` -- a ceiling 90x higher than the `cpu = 11` the examples asked for, with no error at validate, plan or apply.

Verified directly:

```
variable with type object({ default = optional(object({ limits = optional(any, { cpu = 1000 }) }), {}) })
input  { limits = { cpu = 11 } }
output effective_limits = { cpu = 1000 }
```

Corrected in both examples under the touch-and-fix rule, and a validation was added to the root `karpenter` variable so the same mistake now fails loudly instead of being discarded. The validation has to live at the root, because by the time the value reaches the submodule the offending key has already been dropped.
