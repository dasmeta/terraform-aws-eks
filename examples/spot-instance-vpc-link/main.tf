locals {
  cluster_name = "dev"

  node_groups = {
    example = {
      name        = "nodegroup"
      name-prefix = "nodegroup"
      # additional_tags = {
      #   "Name"     = "node"
      #   "ExtraTag" = "ExtraTag"
      # }

      instance_type          = "t3.medium"
      max_capacity           = 1
      disk_size              = 50
      create_launch_template = false
      subnet                 = ["subnet_id"]
      capacity_type          = "SPOT"
    }
  }

  node_groups_default = {
    disk_size      = 50
    instance_types = ["t3.medium"]
    capacity_type  = "SPOT"
  }
}

module "this" {
  source = "../../"

  cluster_name = local.cluster_name

  # TODO: test this
  vpc = {
    link = {
      id                 = "vpc-0abcfb66512c24a4a"
      private_subnet_ids = ["subnet-09bf9e87454585646", "subnet-05e5e04e31dd17b14"]
    }
  }
  node_groups         = local.node_groups
  node_groups_default = local.node_groups_default

  alarms = {
    enabled   = false
    sns_topic = ""
  }
}
