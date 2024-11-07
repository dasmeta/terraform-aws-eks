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

# Prepare for test
data "aws_availability_zones" "available" {}
data "aws_vpcs" "ids" {
  tags = {
    Name = "default"
  }
}
data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpcs.ids.ids[0]
}
