# module "basic" {
#   source = "../.."

#   cluster_name = "test-cluster-345678"
# }

data "aws_availability_zones" "available" {}
data "aws_vpcs" "ids" {
  tags = {
    Name = "default"
  }
}

module "basic" {
  source = "../.."

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = ["subnet-1", "subnet-2"]
    }
  }
  #cidr               = "10.0.0.0" #local.envs[var.env].cidr
  #availability_zones = [] #local.envs[var.env].availability_zones
  #private_subnets    = [] #local.envs[var.env].private_subnets
  #public_subnets     = [] #local.envs[var.env].public_subnets
  # public_subnet_tags        = local.envs[var.env].public_subnet_tags
  # private_subnet_tags       = local.envs[var.env].private_subnet_tags
  # cluster_enabled_log_types = local.envs[var.env].enabled_cluster_log_types

  ### EKS
  # cluster_version = "1.23"
  cluster_name = "test-cluster-345678"
  # manage_aws_auth = true

  users = [
    # {
    #   username = "aram.karapetyan"
    # },
    # {
    #   username = "tigran.muradyan"
    # },
    # {
    #   username = "viktorya.ghazaryan"
    # },
    # {
    #   username = "julia.aghamyan"
    # },
    # {
    #   username = "vahagn.mnjoyan"
    # }
  ]

  # map_roles = local.envs[var.env].map_roles

  # worker_groups = local.envs[var.env].worker_groups

  # worker_groups_launch_template = local.envs[var.env].worker_groups_launch_template

  # workers_group_defaults = {
  #   root_volume_size = 100
  # }

  # ### ALB-INGRESS-CONTROLLER
  # alb_log_bucket_name = local.envs[var.env].alb_log_bucket_name

  # ### FLUENT-BIT
  # fluent_bit_name = local.envs[var.env].fluent_bit_name
  # log_group_name  = local.envs[var.env].log_group_name

  # # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
  # ### METRICS-SERVER
  # # enable_metrics_server = false
  # # metrics_server_name = "metrics-server"

  # external_secrets_namespace = local.envs[var.env].external_secrets_namespace
}
