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

module "this" {
  source = "../.."

  adot_config = {
    "accept_namespace_regex" : "(default|kube-system)",
    "additional_metrics" : [],
    "log_group_name" : "adot-logs"
  }
  cluster_name     = "test-eks-fluent-bit"
  metrics_exporter = "adot"
  node_groups = {
    "dev_nodes" : {
      "desired_size" : 1,
      "max_size" : 1,
      "min_size" : 1
    }
  }
  node_groups_default = {
    "capacity_type" : "SPOT",
    "instance_types" : ["t3.medium"]
  }

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  fluent_bit_configs = {
    configs = {
      inputs                     = templatefile("${path.module}/templates/inputs.yaml.tpl", {})
      outputs                    = templatefile("${path.module}/templates/outputs.yaml.tpl", {})
      filters                    = templatefile("${path.module}/templates/filters.yaml.tpl", {})
      cloudwatch_outputs_enabled = false # have false in case you want also disable default cloudwatch log exporters/outputs
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
  alarms = {
    enabled   = false
    sns_topic = ""
  }
}
