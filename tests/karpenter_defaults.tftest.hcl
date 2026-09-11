# Native plan-time tests for the karpenter submodule.
#
# Providers are mocked so these run with no AWS credentials and no cluster. That bounds what can be
# asserted: values embedding upstream module outputs (the node IAM role name, the interruption queue)
# are unknown under mocks, so assertions here cover configuration-derived behaviour only. Behaviour that
# genuinely needs a cluster -- drain, interruption handling, actual node provisioning -- belongs to the
# live test tiers and is deliberately not faked here.

mock_provider "aws" {
  # The generic mock returns a placeholder string for every attribute, which the aws provider then rejects
  # when it validates assume-role policies as JSON. Give the policy-document data source a valid empty
  # document so planning reaches the checks this file actually exercises.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Random placeholders for these break ARN construction in the upstream module, so give them real shapes.
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-central-1"
      region = "eu-central-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "kubectl" {}

variables {
  cluster_name      = "test-eks-karpenter"
  cluster_version   = "1.34"
  cluster_endpoint  = "https://example.invalid"
  oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLE"
}

# Two replicas need a node in each of two availability zones. With a single subnet that is impossible, and
# the old behaviour was a silently Pending replica: the setup looks highly available and is not.
run "two_replicas_with_one_subnet_is_refused" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids = ["subnet-aaaaaaaa"]
    configs    = { replicas = 2 }
  }

  expect_failures = [
    helm_release.this,
  ]
}

# A single replica is a coherent request on a single-subnet cluster and must not be blocked.
run "one_replica_with_one_subnet_is_allowed" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids = ["subnet-aaaaaaaa"]
    configs    = { replicas = 1 }
  }
}

# The default two-replica configuration plans cleanly when the cluster spans two availability zones.
run "defaults_plan_with_two_subnets" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  }
}

# An explicitly pinned AMI alias must be accepted, so operators can stop drift when they choose to.
run "pinned_ami_alias_is_accepted" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids                = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
    resource_configs_defaults = { default = { nodeClass = { amiAlias = "al2023@v20240807" } } }
  }
}

# Disruption windows must be disableable, since the default is UTC-based and wrong outside central Europe.
run "disruption_windows_can_be_disabled" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids                = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
    resource_configs_defaults = { default = { disruption = { budgets = [{ nodes = "10%" }] } } }
  }
}

# The protected preset exists so that declaring on-demand capacity is a nodeClassRef and nothing else.
# These assert on the rendered NodePool values rather than on the plan succeeding, because the failure this
# guards against -- a field arriving as null instead of being absent -- plans perfectly well.
run "on_demand_preset_supplies_the_whole_pool" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
    resource_configs = {
      nodePools = {
        general     = { weight = 1 }
        "on-demand" = { template = { spec = { nodeClassRef = { name = "on-demand" } } } }
      }
    }
  }

  assert {
    condition     = output.node_pools["on-demand"].weight == 50
    error_message = "the on-demand preset must supply weight, so a pool does not have to restate it"
  }

  assert {
    condition     = output.node_pools["on-demand"].template.spec.taints[0].key == "dedicated"
    error_message = "the on-demand preset must supply its taint, otherwise ordinary workloads land on on-demand capacity"
  }

  assert {
    condition = contains([
      for r in output.node_pools["on-demand"].template.spec.requirements :
      r.values[0] if r.key == "karpenter.sh/capacity-type"
    ], "on-demand")
    error_message = "the on-demand preset must pin capacity-type to on-demand"
  }

  # Admitting the t family makes 2GiB shapes reachable; without this floor karpenter picks a t3a.small.
  assert {
    condition = length([
      for r in output.node_pools["on-demand"].template.spec.requirements :
      r if r.key == "karpenter.k8s.aws/instance-memory" && r.operator == "Gt" && r.values[0] == "3000"
    ]) == 1
    error_message = "the on-demand preset must keep a memory floor above 2GiB now that burstable is allowed"
  }

  assert {
    condition     = output.node_pools["on-demand"].disruption.consolidationPolicy == "WhenEmpty"
    error_message = "on-demand capacity must only ever lose an empty node"
  }

  # The other half of the contract: pools that inherit no weight or taints must not render them as null.
  assert {
    condition     = !can(output.node_pools.general.taints)
    error_message = "a pool with no taints must omit the field entirely, not render taints: null"
  }

  assert {
    condition     = output.node_pools.general.weight == 1
    error_message = "an explicit pool weight must survive the preset merge"
  }
}

# A pool's own taints REPLACE the preset's rather than merging with them. Asserted because the alternative
# -- a half-inherited taint set -- would be a silent scheduling change rather than a visible one.
run "pool_taints_replace_the_preset_taints" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    subnet_ids = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
    resource_configs = {
      nodePools = {
        "on-demand" = {
          template = {
            spec = {
              nodeClassRef = { name = "on-demand" }
              taints       = [{ key = "team", value = "data", effect = "NoSchedule" }]
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(output.node_pools["on-demand"].template.spec.taints) == 1
    error_message = "a pool declaring taints must get exactly what it wrote, not its taints plus the preset's"
  }

  assert {
    condition     = output.node_pools["on-demand"].template.spec.taints[0].key == "team"
    error_message = "the pool's own taint must win over the preset default"
  }

  # The rest of the preset must still apply: only taints were overridden.
  assert {
    condition     = output.node_pools["on-demand"].weight == 50
    error_message = "overriding taints must not discard the rest of the preset"
  }
}
