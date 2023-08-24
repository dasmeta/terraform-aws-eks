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

# test
module "basic" {
  source = "../.."

  cluster_name = "test-cluster-345678"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnet_ids.subnets.ids
    }
  }

  # enable_olm = true
}
