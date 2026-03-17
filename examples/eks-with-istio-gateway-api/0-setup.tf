terraform {
  required_version = "~> 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.31, < 6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

# Domain variable for DNS zones and Gateway API configuration
variable "domain" {
  type        = string
  description = "Domain name for DNS zones and Gateway API configuration"
  default     = "istio.devops.dasmeta.com"
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

# DNS Zones and dns delegation records for domain, NOTE: the domains dns records in sones being created manually as internal/external load balancers being created dynamically based on gateway-api Gateway resources
# Public DNS zone
module "dns_public" {
  source  = "dasmeta/dns/aws"
  version = "1.0.5"

  zone         = var.domain
  create_zone  = true
  private_zone = false
  records      = []
}

# Private DNS zone for routing traffic internally by using separate dns record for domain to internal load balancer
module "dns_private" {
  source  = "dasmeta/dns/aws"
  version = "1.0.5"

  zone         = var.domain
  create_zone  = true
  private_zone = true
  records      = []
  vpc_ids      = data.aws_vpcs.ids.ids
}

# Extract parent zone and subdomain from domain
locals {
  domain_parts = split(".", var.domain)
  subdomain    = local.domain_parts[0]
  parent_zone  = join(".", slice(local.domain_parts, 1, length(local.domain_parts)))
}

## Security group for the external NLB - restricts access to the load balancer from allowed IP only
## NOTE: this can be enabled to restrict access to the external NLB to allowed IP only, we just keep it here for reference example
# resource "aws_security_group" "nlb_restricted" {
#   name        = "istio-gateway-nlb-restricted"
#   description = "Restricts access to Istio Gateway external NLB to allowed IP only"
#   vpc_id      = data.aws_vpcs.ids.ids[0]

#   ingress {
#     description = "HTTPS from allowed IP"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["178.78.131.39/32"] # replace with your allowed IP which you want to whitelist for external NLB access
#   }

#   ingress {
#     description = "HTTP from allowed IP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["178.78.131.39/32"]
#   }

#   egress {
#     description = "Allow all outbound for NLB to reach targets"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# NS delegation record in parent zone (devops.dasmeta.com)
# Creates NS record for "istio" subdomain pointing to the public zone name servers
module "dns_parent_delegation" {
  source  = "dasmeta/dns/aws"
  version = "1.0.5"

  zone         = local.parent_zone
  create_zone  = false
  private_zone = false
  records = [
    {
      name  = local.subdomain
      type  = "NS"
      value = module.dns_public.ns_delegation_set
    }
  ]
}
