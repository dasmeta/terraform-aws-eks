provider "aws" {
  region = "eu-central-1"
}

# `exec` rather than a `token`: an `aws_eks_cluster_auth` token is minted once and lives 15 minutes, which a
# first apply spends almost entirely on creating the cluster and node group before any chart is installed.
# See the note in the module's providers.tf. Requires the AWS CLI v2 on PATH.
provider "helm" {
  kubernetes {
    host                   = module.this.cluster_host
    cluster_ca_certificate = module.this.cluster_certificate

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", "eu-central-1"]
    }
  }
}

# Prepare for test
data "aws_availability_zones" "available" {}
data "aws_vpcs" "ids" {
  tags = {
    Name = "default"
  }
}
data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpcs.ids.ids[0]]
  }
}

locals {
  cluster_name = "test-eks-karpenter-recommended"
}
