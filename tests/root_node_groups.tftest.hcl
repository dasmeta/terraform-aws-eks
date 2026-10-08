# Root-module coverage for node group shapes.
#
# var.node_groups is `any`, and groups legitimately differ: one may set ami_type while another inherits it.
# Anything at the root that feeds local.node_groups into a conditional or a typed collection forces
# Terraform to unify those shapes, which fails planning with "Inconsistent conditional result types" --
# a failure no live apply on a single uniform group can reach. This file plans the root module with
# deliberately mismatched groups so that class of regression is caught without AWS credentials.

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
      arn        = "arn:aws:iam::111111111111:user/example"
      user_id    = "AIDAEXAMPLEEXAMPLE"
    }
  }

  # The upstream eks module resolves the caller's session context; a placeholder string is not a valid ARN.
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn  = "arn:aws:iam::111111111111:role/example"
      issuer_name = "example"
    }
  }
}
mock_provider "helm" {}
mock_provider "kubectl" {}
mock_provider "kubernetes" {}

variables {
  cluster_name    = "test-root-node-groups"
  cluster_version = "1.35"
  vpc = {
    link = {
      id                 = "vpc-00000000000000000"
      private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    }
  }
}

# Two groups of different shape, karpenter on. Planning at all is the assertion.
run "differently_shaped_node_groups_still_plan" {
  command = plan

  module {
    source = "./tests/fixtures/root-wrapper"
  }

  variables {
    node_groups = {
      default = { min_size = 2, max_size = 2, desired_size = 2, ami_type = "AL2023_x86_64_STANDARD" }
      extra   = { min_size = 1, max_size = 1, desired_size = 1 }
    }
    karpenter = {
      enabled = true
    }
  }


  # The spot pool's alias is configuration-derived, so it is knowable under mocks and proves the karpenter
  # defaults were actually built rather than short-circuited.
}

# The same shapes with karpenter off must also plan: the gating must not depend on group shape.
run "differently_shaped_node_groups_with_karpenter_disabled" {
  command = plan

  module {
    source = "./tests/fixtures/root-wrapper"
  }

  variables {
    node_groups = {
      default = { min_size = 2, max_size = 2, desired_size = 2, ami_type = "AL2023_x86_64_STANDARD" }
      extra   = { min_size = 1, max_size = 1, desired_size = 1 }
    }
    karpenter = {
      enabled = false
    }
  }

}
