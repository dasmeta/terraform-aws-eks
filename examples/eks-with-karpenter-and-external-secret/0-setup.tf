terraform {
  required_version = "~> 1.3"

  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      # version = "~>1.14"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "helm" {
  kubernetes {
    host                   = module.this.cluster_host
    cluster_ca_certificate = module.this.cluster_certificate
    token                  = module.this.cluster_token
  }
}

provider "kubectl" {
  host                   = module.this.cluster_host
  cluster_ca_certificate = module.this.cluster_certificate
  token                  = module.this.cluster_token
  load_config_file       = false
}

provider "kubernetes" {
  host                   = module.this.cluster_host
  cluster_ca_certificate = module.this.cluster_certificate
  token                  = module.this.cluster_token
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
  cluster_name = "test-eks-with-karp-and-secret"
  namespace    = "default"
}
