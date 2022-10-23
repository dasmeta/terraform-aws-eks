data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  vpc_name                       = "dev"
  cidr                           = "172.16.0.0/16"
  availability_zones             = data.aws_availability_zones.available.names
  private_subnets                = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets                 = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  cluster_enabled_log_types      = ["audit"]
  cluster_name                   = "dev"
  cluster_endpoint_public_access = true

  users = [
    {
      userarn  = "arn:aws:iam::xxxxxxx:user/test"  # change this whit your account 
      username = "test"
      groups   = ["system:masters"]
    }
  ]
  node_groups = {
    example =  {
      name  = "nodegroup"
      name-prefix     = "nodegroup"
      additional_tags = {
          "Name"      = "node"
          "ExtraTag"  = "ExtraTag"
      }

      instance_type   = "t3.xlarge"
      max_capacity    = 1
      disk_size       = 50
      create_launch_template = false
      subnet = ["subnet_id"]
      capacity_type = "SPOT"
    }
  }

  node_groups_default = {
      disk_size      = 50
      instance_types = ["t3.medium"]
      capacity_type = "SPOT"
    }

  worker_groups = {
    default = {
      name              = "nodes"
      instance_type     = "t3.xlarge"
      capacity_type = "SPOT"
      asg_max_size      = 3
      root_volume_size  = 50
    }
  }

  workers_group_defaults = {
    launch_template_use_name_prefix = true
    launch_template_name            = "default"
    root_volume_type                = "gp2"
    root_volume_size                = 50
  }
}

module "cluster_min" {
  source  = "dasmeta/eks/aws"
  version = "1.4.0"

  cluster_name                = local.cluster_name
  send_alb_logs_to_cloudwatch = false
  users                       = local.users
  vpc_name                    = local.vpc_name
  cidr                        = local.cidr
  availability_zones          = local.availability_zones
  private_subnets             = local.private_subnets
  public_subnets              = local.public_subnets
  account_id                  = data.aws_caller_identity.current.account_id
}
