terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.31, < 6.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
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

# Domain for DNS01 certificate (must be a zone managed in Cloudflare for the token).
variable "domain" {
  type        = string
  description = "Domain name for cert-manager DNS01 certificate"
  default     = "test-cert-dns01-resolve-devops.dasmeta.com"
}

# Cloudflare API token for DNS01 challenge (create at https://dash.cloudflare.com/profile/api-tokens with "Edit zone DNS" permission).
# Pass via TF_VAR_cloudflare_api_token or -var="cloudflare_api_token=..."
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token for cert-manager DNS01 challenge"
  sensitive   = true
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
