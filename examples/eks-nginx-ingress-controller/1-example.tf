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

# test
module "basic" {
  source = "../.."

  cluster_name = "test-cluster-345678"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  alarms = {
    enabled   = false
    sns_topic = ""
  }

  nginx_ingress_controller_config = {
    enabled          = true
    name             = "nginx"
    create_namespace = true
    namespace        = "ingress-nginx"
    replicacount     = 3
    metrics_enabled  = true
  }
}
