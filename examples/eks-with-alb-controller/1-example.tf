module "this" {
  source = "../.."

  cluster_name = "test-with-alb-controller"

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

  enable_ebs_driver            = false
  enable_external_secrets      = false
  enable_node_problem_detector = false
  create_cert_manager          = false
  autoscaling                  = false
  metrics_exporter             = "disabled"

  fluent_bit_configs = local.disabled
  karpenter          = local.disabled
  keda               = local.disabled
  linkerd            = local.disabled
  kyverno            = local.disabled

  external_dns = {
    enabled = true # enable to get dns records created automatically
  }

  alb_load_balancer_controller = {
    enabled = true
    chart = {
      version = "3.3.0"
    }
    iam = {
      attachment_method = "service_account_role_annotation"
    }
    configs = {
      replicaCount = 1
    }
  }

  node_groups = {
    default = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.32"
  wait       = true

  values = [file("${path.module}/http-echo-alb-controller.yaml")]

  depends_on = [module.this]
}
