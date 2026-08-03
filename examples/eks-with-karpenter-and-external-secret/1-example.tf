module "this" {
  # Local source so this example exercises the in-repo module. Switch back to the registry
  # source below once the external-secrets changes are released.
  source = "../.."
  # source  = "dasmeta/eks/aws"
  # version = "2.27.0"
  # external_secrets_chart_version = "0.16.2" # 0.16.x version supports both v1 and v1beta1 api versions, then we need to upgrade secret_store module and apps helm charts values to use new api v1 version, then we can remove/comment out this to get the latest version
  cluster_name = local.cluster_name

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  external_dns = {
    enabled = true
  }

  enable_external_secrets = true # we have to have external secrets operator installed/configured, by default this is set to true, but we explicitly set this here to highlight this option

  users = [
    { username = "terraform" }
  ]
  # metrics_exporter = "adot"
  adot_config = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = []
    log_group_name         = "adot"
  }
  cluster_enabled_log_types = ["audit"]

  node_groups = {
    dev_nodes = {
      # cluster_version: "1.33"
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
            }
          }
          disruption = { # for on-demands nodes use this config to prevent karpenter to colocate/disrupt nodes
            consolidationPolicy = "WhenEmpty"
            consolidateAfter    = "10m"
          }
        }
      }
    }
  }
}

module "secret_store" {
  # Local source so this example exercises the in-repo store changes (IAM role chaining
  # instead of an IAM user with static keys). Switch back to the registry source once released.
  source = "../../../terraform-aws-modules/modules/external-secret-store"
  # source  = "dasmeta/modules/aws//modules/external-secret-store"
  # version = "2.18.1"

  name                         = "app/test"               # {{ .Values.product }}-{{ .Values.env }}
  external_secrets_api_version = "external-secrets.io/v1" # IMPORTANT to upgrade external secret api version as new eks module bring new external secret operator
  namespace                    = local.namespace

  # The store creates its own least-privilege role scoped to secrets named app/test*, and
  # trusts the controller's base role so the controller can assume it. store_role_name_prefix
  # must match on both sides, otherwise the controller's sts:AssumeRole grant won't cover it.
  controller_role_arn    = module.this.external_secrets.controller_role_arn
  store_role_name_prefix = module.this.external_secrets.store_role_name_prefix

  depends_on = [module.this]
}

module "secret_manager" {
  source  = "dasmeta/modules/aws//modules/secret"
  version = "2.6.2"
  # source  = "/Users/tmuradyan/projects/dasmeta/terraform-aws-modules/modules/secret"


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
  version    = "0.3.4"
  namespace  = local.namespace
  wait       = false

  values = [file("${path.module}/http-echo.yaml")]

  depends_on = [module.this]
}
