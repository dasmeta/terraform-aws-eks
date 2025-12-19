module "this" {
  ## the commented tf cloud source and exact version set have been used for testing upgrade from 1.29=>1.30 version, we keep this code for future testings
  # source          = "dasmeta/eks/aws"
  # version         = "2.20.3"
  # cluster_version = "1.29"
  source = "../.."

  cluster_name = local.cluster_name

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    default = {
      desired_size = 1,
      max_size     = 1,
      min_size     = 1
      # taints = {
      #   # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
      #   # The pods that do not tolerate this taint should run on nodes created by Karpenter
      #   addons = {
      #     key    = "CriticalAddonsOnly"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   },
      # }
    }
  }
  node_groups_default = {
    # "capacity_type" : "SPOT", # by default it uses on-demand node, and for karpenter it is preferred to have on-demand nodes where karpenter pods will be placed and the rest of nodes that karpenter will create/manage can be spot also
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
  # metrics_exporter = "cloudwatch"
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

  karpenter = {
    enabled = true
    configs = {
      replicas = 1
    }
    resource_configs_defaults = { # this is optional param, look into karpenter submodule to get available defaults
      limits = {
        cpu = 11 # the default is 10 and we can add limit restrictions on memory also
      }
    }
    resource_configs = {
      nodePools = {
        general = { weight = 1 } # by default it use linux amd64 cpu<=8, memory<=32Gi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
        on-demand = {
          # weight = 0 # by default the weight is 0 and this is lowest priority, we can schedule pod in this not
          template = {
            metadata = {
              labels = {
                nodetype = "on-demand"

              }
            }
            spec = {
              requirements = [
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["on-demand"]
                }
              ]
              taints = [
                {
                  effect = "NoSchedule"
                  key    = "nodegroup"
                  value  = "on-demand"
                }
              ]
            }
          }
          disruption = {
            consolidationPolicy = "WhenEmpty"
            consolidateAfter    = "10m"
          }
        }
      }
    }
  }
}

resource "helm_release" "http_echo_on_demand" {
  name       = "http-echo-on-demand"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.2.10"
  wait       = false

  values = [file("${path.module}/http-echo-on-demand.yaml")]

  depends_on = [module.this]
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.2.10"
  wait       = false

  values = [file("${path.module}/http-echo.yaml")]

  depends_on = [module.this]
}
