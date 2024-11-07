module "this" {
  source = "../.."

  cluster_name = "test-cluster-with-flagger"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnet_ids.subnets.ids
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
  enable_ebs_driver             = false
  enable_external_secrets       = false
  create_cert_manager           = false
  enable_alb_ingress_controller = false
  enable_node_problem_detector  = false
  metrics_exporter              = "disabled"
  fluent_bit_configs = {
    enabled = false
  }

  nginx_ingress_controller_config = {
    enabled          = true
    name             = "nginx"
    create_namespace = true
    namespace        = "ingress-nginx"
    replicacount     = 1
    metrics_enabled  = true
  }

  external_dns = {
    enabled = true
    configs = {
      configs = { sources = ["service", "ingress"] }
    }
  }

  flagger = {
    enabled           = true
    namespace         = "ingress-nginx"
    enable_loadtester = true
    configs = {
      meshProvider = "nginx"
      prometheus = {
        install = true
      }
    }
  }
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.2.7"
  wait       = true

  values = [file("${path.module}/http-echo-canary-eks.yaml")]

  depends_on = [module.this]
}
