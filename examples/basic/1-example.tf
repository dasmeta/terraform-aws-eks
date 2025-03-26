module "this" {
  source = "../.."

  cluster_name = "test-cluster-345678"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  # enable_olm = true
  alarms = {
    enabled   = false
    sns_topic = ""
  }
}
