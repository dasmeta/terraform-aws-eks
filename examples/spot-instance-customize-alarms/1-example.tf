module "cluster_min" {
  source = "../../"

  cluster_name = "test-eks-spot-instances"

  vpc = {
    create = {
      name               = "test-eks-spot-instances"
      cidr               = "10.16.0.0/16"
      availability_zones = data.aws_availability_zones.available.names
      private_subnets    = ["10.16.1.0/24", "10.16.2.0/24", "10.16.3.0/24"]
      public_subnets     = ["10.16.4.0/24", "10.16.5.0/24", "10.16.6.0/24"]
    }
  }
  account_id = data.aws_caller_identity.current.account_id

  node_groups = {
    example = {
      max_capacity = 1
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  node_groups_default = {
    instance_types = ["t3.medium"]
    capacity_type  = "SPOT"
  }

  alarms = {
    sns_topic = "Default"
    custom_values = {
      node_failed = {
        period    = "62"
        threshold = "1"
        statistic = "max"
      }
    }
  }
}
