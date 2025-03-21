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

# can be set via env `export TF_VAR_DOCKER_HUB_USERNAME=<your-dockerhub-username-here>`
variable "DOCKER_HUB_USERNAME" {
  type = string
}

# can be set via env `export TF_VAR_DOCKER_HUB_PASSWORD=<your-dockerhub-personal-access-token-here>`
variable "DOCKER_HUB_PASSWORD" {
  type = string
}

locals {
  cluster_name        = "test-eks-with-docker-auth" # and app namespaces
  namespace           = "dev"
  dockerHubSecretName = "docker-hub-credentials-1"
}

# NOTE: have this credential creation applied at first, by using  for example `tfa --target module.aws_secret_for_docker_hub_credentials`, before applying the main module
# also destroy at first `tfd --target module.this` and then this one
module "aws_secret_for_docker_hub_credentials" {
  source  = "dasmeta/modules/aws//modules/secret"
  version = "2.6.2"

  name                    = local.dockerHubSecretName
  recovery_window_in_days = 0
  value = {
    DOCKER_HUB_USERNAME = var.DOCKER_HUB_USERNAME
    DOCKER_HUB_PASSWORD = var.DOCKER_HUB_PASSWORD
  }
}
