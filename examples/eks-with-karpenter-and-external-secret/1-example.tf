module "this" {
  source = "../.."

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  autoscaler_image_patch = 1
  ebs_csi_version        = "v1.32.0-eksbuild.1"
  adot_version           = "v0.94.1-eksbuild.1"
  users = [
    { username = "terraform" }
  ]
  metrics_exporter = "adot"
  adot_config = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = []
    log_group_name         = "adot"
  }
  cluster_enabled_log_types = ["audit"]

  node_groups = {
    dev_nodes = {
      min_size : 1
      max_size : 2
      desired_size : 2
    }
  }

  node_groups_default = {
    instance_types = ["t3.medium"]
  }

  alarms = {
    enabled   = false
    sns_topic = ""
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
            spec = {
              requirements = [
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["on-demand"]
                }
              ]
            }
          }
        }
      }
    }
  }
}

module "secret_store" {
  source  = "dasmeta/modules/aws//modules/external-secret-store"
  version = "2.18.1"

  name                         = "app/test"                    # {{ .Values.product }}-{{ .Values.env }}
  external_secrets_api_version = "external-secrets.io/v1beta1" # IMPORTANT to upgrade external secret api version as new eks module bring new external secret operator

  depends_on = [module.this]
}

module "secret_manager" {
  source  = "dasmeta/modules/aws//modules/secret"
  version = "2.6.2"

  name                    = "app/test/http-echo"
  recovery_window_in_days = 0
  value = {
    AN_TEST_SECRET_ENV = "test-value"
  }
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  version    = "0.2.10"
  namespace  = "default"
  wait       = false

  values = [file("${path.module}/http-echo.yaml")]

  depends_on = [module.this]
}
