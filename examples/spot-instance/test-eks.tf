data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  vpc_name                  = "dasmeta-test"
  cidr                      = "10.10.0.0/16"
  availability_zones        = data.aws_availability_zones.available.names
  private_subnets           = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnets            = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]
  cluster_enabled_log_types = ["audit"]

  # When you create EKS, API server endpoint access default is public. When you use private this variable value should be equal false.
  cluster_endpoint_public_access = true
  public_subnet_tags = {
    "kubernetes.io/cluster/dasmeta-test-new3" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/dasmeta-test-new3" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
  cluster_name        = "dasmeta-test-new3"
  alb_log_bucket_name = "dasmeta-test-1"

  fluent_bit_name           = "fluent-bit-test"
  log_group_name            = "fluent-bit-cloudwatch"
  enable_prometheus_metrics = true
  users = [
    {
      username = "username"  #NOTE CHANGE it with yours
      group    = ["system:masters"]
    }
  ]
}

module "cluster_min" {
  source  = "dasmeta/eks/aws"
  version = "v1.2.2"

  cluster_name        = local.cluster_name
  users               = local.users
  vpc_name            = local.vpc_name
  cidr                = local.cidr
  availability_zones  = local.availability_zones
  private_subnets     = local.private_subnets
  public_subnets      = local.public_subnets
  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags
  alb_log_bucket_name = local.alb_log_bucket_name
  account_id          = data.aws_caller_identity.current.account_id
}
