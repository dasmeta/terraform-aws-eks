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

  adot_config = {
    accept_namespace_regex = "(default|runner|awattgarde|prefect-jobs)"
    log_group_name         = "/aws/containerinsights/prod/adot"

    # to export additional metrics
    additional_metrics = [
      "pod_memory_working_set",
      "pod_cpu_usage_total"
    ]
  }

  # to collect additional metrics from kube-state-metrics
  prometheus_metrics = [
    "kube_deployment_spec_replicas",
    "kube_deployment_status_replicas_available"
  ]

  alarms = {
    enabled   = false
    sns_topic = ""
  }
}
