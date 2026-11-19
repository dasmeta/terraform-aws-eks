# NEGATIVE case: the run in this file is EXPECTED TO FAIL, so `terraform test` on it is red when the module
# is correct. Run it only through ./run.sh, which requires it to fail with the guard's own message. One run
# per file, because terraform test skips the rest of a file after a failed run. A plain `terraform test` at
# the repository root does not pick this directory up.
#
# Why not `expect_failures` in tests/: it accepts only objects of the module under test, and the guard
# (data.aws_partition.ami_type_guard in data.tf) sits one level down, behind tests/fixtures/root-wrapper.
# Pointing a run at the root module directly fails first on the sensitive cluster_token output (see the
# wrapper's header), so that is not an option either.

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
  cluster_name = "test-al2-guard"
  vpc = {
    link = {
      id                 = "vpc-00000000000000000"
      private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    }
  }
  node_groups = {
    default = { min_size = 2, max_size = 2, desired_size = 2, ami_type = "AL2_x86_64" }
  }
  karpenter = {
    enabled = false
  }
}

# The boundary: 1.32 is the last version with an AL2 AMI (its passing side is in tests/root_node_groups).
run "al2_on_1_33_is_rejected" {
  command = plan
  module {
    source = "./tests/fixtures/root-wrapper"
  }
  variables {
    cluster_version = "1.33"
  }
}
