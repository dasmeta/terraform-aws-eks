locals {
  cluster_enabled_log_types      = ["audit"]
  cluster_name                   = "test"
  cluster_endpoint_public_access = true

  # Prod Parameters
  node_groups_default = {
    create_launch_template = false
    launch_template_name   = ""
    disk_size              = 50
  }
  node_groups = {
    regular = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }

  users = ["**USERS**"]

  map_roles = ["**ROLES**"]
}

module "cluster_min" {
  source = "../.."

  enable_ebs_driver   = true
  cluster_name        = local.cluster_name
  cluster_version     = "1.29"
  users               = local.users
  map_roles           = local.map_roles
  node_groups_default = local.node_groups_default
  node_groups         = local.node_groups

  vpc = {
    link = {
      id                 = "vpc-1234"
      private_subnet_ids = ["subent-1", "subnet-2"]
    }
  }

  alarms = { enabled = false }
}
