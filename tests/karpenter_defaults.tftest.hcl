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
