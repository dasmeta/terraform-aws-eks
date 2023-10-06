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

module "this" {
  source = "../.."

  account_id = "0000000000"
  adot_config = {
    "accept_namespace_regex" : "(default|kube-system)",
    "additional_metrics" : [],
    "log_group_name" : "adot-logs"
  }
  cluster_enabled_log_types = ["audit"]
  cluster_name              = "eks-dev"
  cluster_version           = "1.27"
  metrics_exporter          = "adot"
  node_groups = {
    "dev_nodes" : {
      "desired_size" : 2,
      "max_capacity" : 5,
      "max_size" : 5,
      "min_size" : 2
    }
  }
  node_groups_default = {
    "capacity_type" : "SPOT",
    "instance_types" : ["t3.medium"]
  }
  send_alb_logs_to_cloudwatch = false
  users = [
    { "username" : "dasmeta" },
  ]

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnet_ids.subnets.ids
    }
  }

  fluent_bit_configs = {
    config = {
      inputs  = templatefile("${path.module}/templates/inputs.yaml.tpl", {})
      outputs = templatefile("${path.module}/templates/outputs.yaml.tpl", {})
      filters = templatefile("${path.module}/templates/filters.yaml.tpl", {})
    }
    drop_namespaces = [
      "kube-system",
      "opentelemetry-operator-system",
      "adot",
      "cert-manager"
    ]
    additional_log_filters = [
      "ELB-HealthChecker",
      "Amazon-Route53-Health-Check-Service",
    ]
    log_filters = [
      "ELB-HealthChecker",
      "Amazon-Route53-Health-Check-Service",
      "kube-probe",
      "health",
      "prometheus",
      "liveness"
    ]
  }
}
