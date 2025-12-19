module "this" {
  source = "../.."

  cluster_name = "eks-with-event-exporter"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    "default" : {
      "desired_size" : 1,
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

  event_exporter = {
    enabled = true

    configs = {
      config = {
        receivers = [
          {
            name = "webhook-prod"
            webhook = {
              endpoint = "https://n8n.dasmeta.com/webhook/<webhook-id>?accountId=<account-id>"
            }
          }
        ]
        route = {
          routes = [
            {
              match = [{ receiver : "webhook-prod" }]
            }
          ]
        }
      }
    }
  }
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.10"
  wait       = true

  values = [file("${path.module}/eks-with-event-exporter.yaml")]

  depends_on = [module.this]
}
