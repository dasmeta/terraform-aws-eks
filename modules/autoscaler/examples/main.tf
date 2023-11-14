data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  vpc_name           = "cluster"
  cidr               = "172.16.0.0/16"
  availability_zones = data.aws_availability_zones.available.names
  private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  public_subnet_tags = {
    "kubernetes.io/cluster/dev" = "shared"
    "kubernetes.io/role/elb"    = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/dev"       = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
  cluster_enabled_log_types      = ["audit"]
  cluster_name                   = "dev"
  cluster_endpoint_public_access = true

  node_groups = {
    regular = {
      instance_types = ["t3.medium"]
    }
  }

  node_groups_default = {
    create_launch_template = false
    launch_template_name   = ""
    disk_size              = 50
  }
}

module "cluster_min" {
  #source  = "dasmeta/eks/aws"
  #version  = "1.15.3"

  cluster_name                = local.cluster_name
  send_alb_logs_to_cloudwatch = false
  alb_log_bucket_name         = "ingress-controller-log-bucket"
  cluster_version             = "1.23"
  vpc_name                    = local.vpc_name
  cidr                        = local.cidr
  node_groups_default         = local.node_groups_default
  node_groups                 = local.node_groups
  availability_zones          = local.availability_zones
  private_subnets             = local.private_subnets
  public_subnets              = local.public_subnets
  public_subnet_tags          = local.public_subnet_tags
  private_subnet_tags         = local.private_subnet_tags
  account_id                  = data.aws_caller_identity.current.account_id
  ### Autoscaling part
  autoscaling              = true
  autoscaler_image_patch   = 0 #(Optional)
  scale_down_unneeded_time = 2 #(Scale down unneeded time in minutes, default is 2 minutes)
}
