# Plan-time tests for the on-demand AMI pin, covering the cases a live apply on a single homogeneous
# AL2023 node group cannot reach: differently shaped node groups, a customer-owned image, a per-group
# family override, and an explicit consumer pin that must skip the lookup entirely.
#
# These target the karpenter submodule, where the lookup lives. Providers are mocked, so the discovered
# AMI itself is a placeholder -- what is asserted is which SHAPE the node class takes and whether the
# lookup runs at all, both of which are decided by configuration.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
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

  # A managed node group running an image THIS ACCOUNT built, which the "self" entry in the lookup's owners
  # list covers. Its name does not contain "al2023" but its description does, so this also exercises the
  # description arm of the family derivation -- the arm that matters when the image is not an official EKS
  # one and cannot be recognised from its name.
  #
  # Note what this canNOT assert: mocks do not evaluate the owners filter, so no test here proves an image
  # from an unlisted account is rejected. That path needs a real AWS call.
  mock_data "aws_instances" {
    defaults = {
      ids = ["i-0ffffffffffffffff", "i-00000000000000001"]
    }
  }
  mock_data "aws_instance" {
    defaults = {
      ami = "ami-0selfbuiltimage00"
    }
  }
  mock_data "aws_ami" {
    defaults = {
      id           = "ami-0selfbuiltimage00"
      name         = "my-org-hardened-al2023-x86_64-1.35"
      architecture = "x86_64"
      description  = "Hardened build of Amazon Linux 2023"
    }
  }
}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  cluster_name      = "test-on-demand-ami"
  cluster_version   = "1.35"
  cluster_endpoint  = "https://example.invalid"
  oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLE"
  subnet_ids        = ["subnet-00000000000000001", "subnet-00000000000000002"]
  configs = {
    replicas = 1
  }
}

# The pin applies by default, and the family comes off the image that was found -- not from configuration.
# The mocked AMI is a self-built image whose name does not contain "al2023" but whose DESCRIPTION says
# Amazon Linux 2023, so this also covers the description arm of the family derivation.
run "on_demand_pin_applies_and_family_comes_from_the_image" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  assert {
    condition     = local.onDemandAmiAuto == true
    error_message = "With no consumer AMI override the pin should be derived automatically"
  }

  assert {
    condition     = jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms) == jsonencode([{ id = "ami-0selfbuiltimage00" }])
    error_message = "The on-demand class should carry the discovered AMI id, got ${jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms)}"
  }

  assert {
    condition     = local.defaultEc2NodeClassOnDemand.amiFamily == "AL2023"
    error_message = "amiFamily must be derived from the found image and is mandatory beside an id, got ${jsonencode(try(local.defaultEc2NodeClassOnDemand.amiFamily, null))}"
  }

  # The spot pool is deliberately left tracking the newest image.
  assert {
    condition     = jsonencode(local.defaultEc2NodeClass.amiSelectorTerms) == jsonencode([{ alias = "al2023@latest" }])
    error_message = "The default/spot pool must keep the alias, got ${jsonencode(local.defaultEc2NodeClass.amiSelectorTerms)}"
  }
}

# An explicit amiSelectorTerms must win outright AND switch the lookup off, so a cluster with no managed
# node group instances can still plan.
run "explicit_ami_selector_terms_wins_and_skips_the_lookup" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs_defaults = {
      "on-demand" = {
        nodeClass = {
          amiSelectorTerms = [{ id = "ami-0deadbeefdeadbeef" }]
          amiFamily        = "AL2023"
        }
      }
    }
  }

  assert {
    condition     = local.onDemandAmiAuto == false
    error_message = "An explicit amiSelectorTerms must disable the derivation"
  }

  assert {
    condition     = jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms) == jsonencode([{ id = "ami-0deadbeefdeadbeef" }])
    error_message = "The consumer's own amiSelectorTerms must be used verbatim"
  }
}

# An explicit amiAlias must also switch the lookup off, and must NOT be beaten by a derived id -- the
# submodule prefers amiSelectorTerms, so a derived one would silently override the alias they set.
run "explicit_ami_alias_wins_and_skips_the_lookup" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs_defaults = {
      "on-demand" = {
        nodeClass = {
          amiAlias = "al2023@v20260401"
        }
      }
    }
  }

  assert {
    condition     = local.onDemandAmiAuto == false
    error_message = "An explicit amiAlias must disable the derivation"
  }

  assert {
    condition     = jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms) == jsonencode([{ alias = "al2023@v20260401" }])
    error_message = "A consumer amiAlias must not be overridden by a derived id, got ${jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms)}"
  }

  # No id means no mandatory family, and none should be invented.
  assert {
    condition     = try(local.defaultEc2NodeClassOnDemand.amiFamily, null) == null
    error_message = "An alias selector needs no amiFamily, got ${jsonencode(try(local.defaultEc2NodeClassOnDemand.amiFamily, null))}"
  }
}

# A consumer amiFamily must beat the derived one, while the derived id still applies.
run "consumer_ami_family_overrides_the_derived_one" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs_defaults = {
      "on-demand" = {
        nodeClass = {
          amiFamily = "Bottlerocket"
        }
      }
    }
  }

  assert {
    condition     = local.defaultEc2NodeClassOnDemand.amiFamily == "Bottlerocket"
    error_message = "An explicitly set amiFamily must win over the derived one"
  }

  assert {
    condition     = local.onDemandAmiAuto == true
    error_message = "Setting only amiFamily must still leave the id derivation on"
  }
}

# --- review round 2 ---------------------------------------------------------------------------------------
# The direct EC2NodeClass override path must switch discovery off just like the preset path. Discovery is
# forced to find NO managed instance here: if the gate missed this path, the lookup would run and its
# postcondition would fail the plan.
run "direct_ec2nodeclass_override_skips_the_lookup" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs = {
      nodePools = { general = {} }
      ec2NodeClasses = {
        "on-demand" = {
          amiSelectorTerms = [{ id = "ami-0directpin000000" }]
          amiFamily        = "AL2023"
        }
      }
    }
  }

  override_data {
    target = data.aws_instances.managed_nodes
    values = { ids = [] }
  }

  assert {
    condition     = local.onDemandAmiAuto == false
    error_message = "A direct ec2NodeClasses pin must disable the derivation"
  }
}

# A self-built AL2 image says so only in its description. It must be recognised, not defaulted to AL2023.
run "self_built_al2_is_recognised_from_its_description" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0selfbuiltal2000"
      name         = "org-hardened-node"
      description  = "Hardened Amazon Linux 2"
      architecture = "x86_64"
    }
  }

  assert {
    condition     = local.defaultEc2NodeClassOnDemand.amiFamily == "AL2"
    error_message = "Expected AL2 from the description, got ${jsonencode(try(local.defaultEc2NodeClassOnDemand.amiFamily, null))}"
  }
}

run "renamed_bottlerocket_is_recognised" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0renamedbr000000"
      name         = "org-br-node"
      description  = "Bottlerocket OS 1.20.0"
      architecture = "x86_64"
    }
  }

  assert {
    condition     = local.defaultEc2NodeClassOnDemand.amiFamily == "Bottlerocket"
    error_message = "Expected Bottlerocket, got ${jsonencode(try(local.defaultEc2NodeClassOnDemand.amiFamily, null))}"
  }
}

# Metadata that names no known family must FAIL rather than fall back to AL2023.
run "unknown_family_fails_rather_than_guessing" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0unknownfamily00"
      name         = "org-node"
      description  = "Ubuntu 22.04 LTS"
      architecture = "x86_64"
    }
  }

  expect_failures = [data.aws_ami.managed_node]
}

# ...and an explicit family is the documented way through.
run "unknown_family_is_accepted_with_an_explicit_family" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs_defaults = {
      "on-demand" = { nodeClass = { amiFamily = "AL2" } }
    }
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0unknownfamily00"
      name         = "org-node"
      description  = "Ubuntu 22.04 LTS"
      architecture = "x86_64"
    }
  }

  assert {
    condition     = local.defaultEc2NodeClassOnDemand.amiFamily == "AL2"
    error_message = "The explicit amiFamily must be used"
  }
}

# The preset requires amd64, so discovery is restricted to x86_64 instances...
run "default_preset_restricts_discovery_to_x86" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  assert {
    condition     = local.onDemandEc2Archs == ["x86_64"]
    error_message = "Expected discovery restricted to x86_64, got ${jsonencode(local.onDemandEc2Archs)}"
  }
}

# ...and an ARM image is refused even if one gets through, rather than pinned into amd64 pools.
run "arm_image_is_refused_for_amd64_pools" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0armimage0000000"
      name         = "amazon-eks-node-al2023-arm64-standard-1.35-v20260930"
      description  = "EKS-optimized Kubernetes node based on Amazon Linux 2023"
      architecture = "arm64"
    }
  }

  expect_failures = [data.aws_ami.managed_node]
}

# A pool on the on-demand class that declares its own arch replaces the preset's, so an ARM pool
# discovers from ARM instances and accepts an ARM image.
run "arm_pool_on_the_class_discovers_arm" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs = {
      nodePools = {
        protected-arm = {
          template = {
            spec = {
              nodeClassRef = { name = "on-demand" }
              requirements = [{ key = "kubernetes.io/arch", operator = "In", values = ["arm64"] }]
            }
          }
        }
      }
    }
  }

  override_data {
    target = data.aws_ami.managed_node
    values = {
      id           = "ami-0armimage0000000"
      name         = "amazon-eks-node-al2023-arm64-standard-1.35-v20260930"
      description  = "EKS-optimized Kubernetes node based on Amazon Linux 2023"
      architecture = "arm64"
    }
  }

  assert {
    condition     = local.onDemandEc2Archs == ["arm64"]
    error_message = "Expected discovery restricted to arm64, got ${jsonencode(local.onDemandEc2Archs)}"
  }
}

# Two pools on the class with no architecture in common cannot share one pinned image.
run "pools_with_no_common_arch_fail" {
  command = plan

  module {
    source = "./modules/karpenter"
  }

  variables {
    resource_configs = {
      nodePools = {
        protected-x86 = { template = { spec = { nodeClassRef = { name = "on-demand" } } } }
        protected-arm = {
          template = {
            spec = {
              nodeClassRef = { name = "on-demand" }
              requirements = [{ key = "kubernetes.io/arch", operator = "In", values = ["arm64"] }]
            }
          }
        }
      }
    }
  }

  expect_failures = [data.aws_instances.managed_nodes]
}
