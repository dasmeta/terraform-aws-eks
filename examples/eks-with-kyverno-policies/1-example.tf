module "this" {
  source = "../.."

  cluster_name = "eks-with-kyverno-policies"

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
    enabled = false
  }
  # external_dns = {
  #   enabled = false
  # }
  karpenter = {
    enabled = false
  }
  keda = {
    enabled = false
  }
  linkerd = {
    enabled = false
  }

  # enabled components
  alb_load_balancer_controller = {
    enabled = true
  }

  ## here we have tests codes for external_dns and event_exporter using bitnamilegacy, we commented out this ones to have only common autoswitch enabled
  # external_dns = {
  #   enabled = true
  # }

  # event_exporter = {
  #   enabled = true
  #   configs = {
  #     config = {
  #       receivers = [
  #         {
  #           name = "webhook-prod"
  #           webhook = {
  #             endpoint = "https://n8n.dasmeta.com/webhook/<n8n-webhook-trigger-id>?accountId=<accountId-in-cloudbrowser>" # not a real one
  #           }
  #         }
  #       ]
  #       route = {
  #         routes = [
  #           {
  #             match = [{ receiver : "webhook-prod" }]
  #           }
  #         ]
  #       }
  #     }
  #   }
  # }

  kyverno = {
    enabled  = true # it enabled by default with "bitnami-to-bitnamilegacy" set, but we explicitly enable here for this example
    policies = ["bitnami-to-bitnamilegacy"]
  }
}

# after install it will pull mysql image from bitnamilegacy repository instead of deprecated/removed bitnami
resource "helm_release" "http_echo" {
  name       = "mysql"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mysql"
  namespace  = "default"
  version    = "14.0.3"
  wait       = true

  values = [jsonencode({
    primary = { persistence : { enabled : false } }
  })]

  depends_on = [module.this]
}
