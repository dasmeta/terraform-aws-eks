module "this" {
  source = "../.."

  cluster_name = "eks-with-s3-csi"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    "default" : {
      "desired_size" : 1,
      "max_capacity" : 1,
      "max_size" : 1,
      "min_size" : 1
    }

  }
  node_groups_default = {
    "capacity_type" : "SPOT",
    "instance_types" : ["t3.medium"]
  }

  alarms = {
    enabled   = false
    sns_topic = ""
  }
  enable_ebs_driver            = false
  enable_external_secrets      = false
  create_cert_manager          = false
  enable_node_problem_detector = false
  metrics_exporter             = "disabled"
  fluent_bit_configs = {
    enabled = false
  }

  nginx_ingress_controller_config = {
    enabled      = true
    replicacount = 1
  }

  external_dns = {
    enabled = true
    configs = {
      configs = { sources = ["service", "ingress"] }
    }
  }

  karpenter = {
    enabled = true
    configs = {
      replicas = 1
    }
  }

  s3_csi = {
    enabled = true
  }
}

module "s3_bucket" {
  source  = "dasmeta/s3/aws"
  version = "1.3.2"

  name = "test-eks-with-s3-csi-dasmeta-bucket"

  lifecycle_rules = [
    {
      id      = "remove-after-1-day"
      enabled = true

      expiration = {
        days = 1
      }

      filter = {
        object_size_greater_than = 0
      }
    }
  ]
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.10"
  wait       = true

  values = [file("${path.module}/http-echo-eks-with-s3-csi.yaml")]

  depends_on = [module.this]
}

resource "helm_release" "test_cronjob" {
  name       = "test-cronjob"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base-cronjob"
  namespace  = "default"
  version    = "0.1.22"
  wait       = true

  values = [file("${path.module}/test-cronjob.yaml")]

  depends_on = [module.this]
}
