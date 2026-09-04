# Config-combination matrix for the karpenter submodule.
#
# Complements karpenter_defaults.tftest.hcl, which covers the single-axis cases. This file crosses the axes
# that interact: replicas against subnet count, node pools against their defaults, the protected pool against
# the disruption windows, and operator overrides against module defaults.
#
# Providers are mocked, so this needs no AWS credentials and no cluster. That bounds what can be asserted:
# values embedding upstream module outputs (node IAM role name, interruption queue) are unknown under mocks,
# so most runs assert "this combination plans at all". That is not a weak assertion -- a mis-nested object or
# a bad merge fails here, and terraform validate does not catch either, because the root module types these
# inputs as `any` and defers the check to plan time. A real example carried exactly that bug undetected.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_region" {
    defaults = { name = "eu-central-1", region = "eu-central-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
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

# ---------------------------------------------------------------------------
# Axis: chart versions. Guards against the module drifting behind the charts it owns.
# ---------------------------------------------------------------------------

run "chart_versions_are_current" {
  command = plan
  module { source = "./modules/karpenter" }
  variables { subnet_ids = ["subnet-a", "subnet-b"] }

  assert {
    condition     = helm_release.this.version == "1.14.1"
    error_message = "karpenter chart default drifted from 1.14.1"
  }
  assert {
    condition     = helm_release.this_crds.version == helm_release.this.version
    error_message = "the CRD chart must track the controller chart version exactly"
  }
  assert {
    condition     = helm_release.karpenter_nodes.version == "0.1.2"
    error_message = "karpenter-nodes chart default drifted from 0.1.2"
  }
}

# ---------------------------------------------------------------------------
# Axis: replicas x subnet count. The precondition must fire on the unsatisfiable
# combinations and stay silent on the coherent ones, including at the default.
# ---------------------------------------------------------------------------

run "default_replicas_with_one_subnet_is_refused" {
  command = plan
  module { source = "./modules/karpenter" }
  # No explicit replicas: the default of 2 must still be checked, not silently exempted.
  variables { subnet_ids = ["subnet-a"] }
  expect_failures = [helm_release.this]
}

run "three_replicas_with_two_subnets_is_allowed" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    configs    = { replicas = 3 }
  }
}

run "three_subnets_three_replicas" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]
    configs    = { replicas = 3 }
  }
}

# ---------------------------------------------------------------------------
# Axis: controller resources. An operator must be able to put a cpu limit back,
# and to supply requests only.
# ---------------------------------------------------------------------------

run "operator_can_restore_a_cpu_limit" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    controller_resources = {
      requests = { cpu = "500m", memory = "512Mi" }
      limits   = { cpu = "1", memory = "1Gi" }
    }
  }
}

run "requests_only_no_limits_at_all" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    controller_resources = {
      requests = { cpu = "1", memory = "2Gi" }
      limits   = { cpu = null, memory = null }
    }
  }
}

# ---------------------------------------------------------------------------
# Axis: AMI alias families. Each supported family must render.
# ---------------------------------------------------------------------------

run "ami_alias_al2" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    ami_alias  = "al2@latest"
  }
}

run "ami_alias_bottlerocket_pinned" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    ami_alias  = "bottlerocket@v1.20.4"
  }
}

# ---------------------------------------------------------------------------
# Axis: disruption windows. Empty, multiple, and reason overrides.
# ---------------------------------------------------------------------------

run "two_windows_compose" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    # Two windows, e.g. a business-hours block plus a nightly batch-window block.
    # Karpenter resolves multiple budgets most-restrictive-wins.
    disruption_windows = [
      { schedule = "0 6 * * mon-fri", duration = "12h", reasons = ["Drifted", "Underutilized"], nodes = "0" },
      { schedule = "0 22 * * *", duration = "4h", reasons = ["Underutilized"], nodes = "0" },
    ]
  }
}

run "window_blocking_empty_too" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    # Blocking Empty as well is legal but forgoes free savings; it must still render.
    disruption_windows = [
      { schedule = "0 6 * * mon-fri", duration = "13h", reasons = ["Drifted", "Underutilized", "Empty"], nodes = "0" },
    ]
  }
}

run "window_permitting_some_disruption" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids         = ["subnet-a", "subnet-b"]
    disruption_windows = [{ schedule = "0 6 * * mon-fri", duration = "12h", reasons = ["Underutilized"], nodes = "5%" }]
  }
}

# ---------------------------------------------------------------------------
# Axis: protected pool x windows x custom pools. These interact in locals.
# ---------------------------------------------------------------------------

run "protected_pool_with_custom_taint_and_requirements" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    protected_node_pool = {
      enabled     = true
      name        = "critical"
      weight      = 50
      taint_key   = "example.io/critical"
      taint_value = "yes"
      limits      = { cpu = 50, memory = "200Gi" }
      requirements = [
        { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
        { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
      ]
    }
  }
}

run "protected_pool_with_windows_disabled" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids          = ["subnet-a", "subnet-b"]
    protected_node_pool = { enabled = true }
    disruption_windows  = []
  }
}

# ---------------------------------------------------------------------------
# Axis: resource_configs x resource_configs_defaults. This is where the real bug lived:
# a top-level `limits` instead of one nested under `default` passes terraform validate
# and fails at plan, because the root module types this input as `any`.
# ---------------------------------------------------------------------------

run "custom_pools_with_correctly_nested_defaults" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    resource_configs_defaults = {
      default = {
        limits = { cpu = 11 }
      }
    }
    resource_configs = {
      nodePools = {
        general = { weight = 1 }
        on-demand = {
          template = {
            spec = {
              requirements = [{ key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] }]
              taints       = [{ key = "nodegroup", value = "on-demand", effect = "NoSchedule" }]
            }
          }
          disruption = { consolidationPolicy = "WhenEmpty", consolidateAfter = "10m" }
        }
      }
    }
  }
}

# A pool that declares its own budgets OWNS them: the module's windows are not appended. Appending would
# narrow a hand-tuned window rather than defer to it, because karpenter resolves budgets
# most-restrictive-wins. One production cluster already runs its own 16h daily window tuned to its timezone.
run "pool_declaring_its_own_budgets_keeps_them" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    resource_configs = {
      nodePools = {
        general = {
          disruption = {
            budgets = [
              { nodes = "10%" },
              { nodes = "0", schedule = "0 12 * * *", duration = "16h", reasons = ["Drifted", "Underutilized"] },
            ]
          }
        }
      }
    }
  }
}

# A pool with no budget opinion still receives the module default plus the configured windows.
run "pool_without_budget_opinion_gets_module_windows" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids       = ["subnet-a", "subnet-b"]
    resource_configs = { nodePools = { general = { weight = 1 } } }
  }
}

run "pool_pinned_to_the_gpu_node_class" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    resource_configs = {
      nodePools = {
        gpu = {
          template = {
            spec = {
              nodeClassRef = { group = "karpenter.k8s.aws", kind = "EC2NodeClass", name = "gpu" }
            }
          }
        }
      }
    }
  }
}

run "extra_node_class_alongside_the_defaults" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    resource_configs = {
      ec2NodeClasses = {
        custom = {
          amiFamily        = "AL2023"
          amiSelectorTerms = [{ alias = "al2023@latest" }]
        }
      }
      nodePools = { general = { weight = 1 } }
    }
  }
}

# ---------------------------------------------------------------------------
# Axis: drain ceiling.
# ---------------------------------------------------------------------------

run "termination_grace_period_can_be_unset" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids               = ["subnet-a", "subnet-b"]
    termination_grace_period = null
  }
}

run "everything_at_once" {
  command = plan
  module { source = "./modules/karpenter" }
  # The full recommended shape, to catch interactions no single-axis run would.
  variables {
    subnet_ids               = ["subnet-a", "subnet-b", "subnet-c"]
    configs                  = { replicas = 2 }
    ami_alias                = "al2023@v20240807"
    termination_grace_period = "12h"
    controller_resources     = { requests = { cpu = "500m", memory = "1Gi" }, limits = { memory = "2Gi" } }
    protected_node_pool      = { enabled = true, limits = { cpu = 20 } }
    disruption_windows = [
      { schedule = "0 12 * * mon-fri", duration = "13h", reasons = ["Drifted", "Underutilized"], nodes = "0" },
    ]
    resource_configs_defaults = { default = { limits = { cpu = 500 } } }
    resource_configs          = { nodePools = { general = { weight = 1 } } }
  }
}

# ---------------------------------------------------------------------------
# Guard for the silent-drop trap. Terraform object conversion discards attributes the
# target type does not declare, so a mis-nested `limits` never reaches the submodule and
# the module default applies instead -- with no error anywhere. Two real examples shipped
# that way. The root variable now rejects it; this run proves the module still accepts the
# CORRECT nesting, so the validation cannot drift into rejecting valid input.
# ---------------------------------------------------------------------------

run "correctly_nested_gpu_and_default_together" {
  command = plan
  module { source = "./modules/karpenter" }
  variables {
    subnet_ids = ["subnet-a", "subnet-b"]
    resource_configs_defaults = {
      default = { limits = { cpu = 11 } }
      gpu     = { limits = { cpu = 4 } }
    }
  }
}
