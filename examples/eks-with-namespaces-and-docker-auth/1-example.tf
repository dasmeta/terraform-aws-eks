module "this" {
  source = "../.."

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

  keda = {
    enabled = false
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

  namespaces_and_docker_auth = {
    enabled = true
    list    = [local.namespace]
    labels = {
      mylabel = "myvalue"
    }
    dockerAuth = {
      enabled                 = true
      refreshInterval         = "1m" # we set this small value just for testing. as this value will not be changed, just leave the default 1h value
      secretManagerSecretName = local.dockerHubSecretName
    }
  }

  # depends_on = [module.aws_secret_for_docker_hub_credentials] # it is supposed we wait for module.aws_secret_for_docker_hub_credentials be applied and then apply this/main module to create cluster as the secret
}

module "secret_store" {
  source  = "dasmeta/modules/aws//modules/external-secret-store"
  version = "2.18.1"

  name                         = "app/test"                    # {{ .Values.product }}-{{ .Values.env }}
  external_secrets_api_version = "external-secrets.io/v1beta1" # IMPORTANT to upgrade external secret api version as new eks module bring new external secret operator
  namespace                    = local.namespace

  depends_on = [module.this.namespaces_and_docker_auth_helm_metadata]
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
  version    = "0.3.4"
  namespace  = local.namespace
  wait       = false

  values = [file("${path.module}/http-echo.yaml")]

  depends_on = [module.this.external_secret_deployment, module.this.namespaces_and_docker_auth_helm_metadata]
}
