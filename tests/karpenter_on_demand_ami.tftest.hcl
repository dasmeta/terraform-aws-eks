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

  # A managed node group instance running a CUSTOMER-OWNED image. The owner is deliberately not the EKS
  # official account: an owners filter on the image-id lookup would exclude this and fail a supported
  # configuration, which is why there is no owners filter.
  mock_data "aws_instances" {
    defaults = {
      ids = ["i-0ffffffffffffffff", "i-00000000000000001"]
    }
  }
  mock_data "aws_instance" {
    defaults = {
      ami = "ami-0customerownedimage"
    }
  }
  mock_data "aws_ami" {
    defaults = {
      id          = "ami-0customerownedimage"
      name        = "my-org-hardened-al2023-x86_64-1.35"
      description = "Hardened build of Amazon Linux 2023"
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
# The mocked AMI is a customer build whose name does not contain "al2023" but whose DESCRIPTION says
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
    condition     = jsonencode(local.defaultEc2NodeClassOnDemand.amiSelectorTerms) == jsonencode([{ id = "ami-0customerownedimage" }])
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
