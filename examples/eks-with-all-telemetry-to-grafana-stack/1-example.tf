# For having grafana stack be used as target to collected metric/logs/traces we just disable adot and fluent-bit in eks module and install our grafana stack module
# So that logs and metrics being collected natively by prometheus and loki.promtail and tempo service endpoint(otel htt/grpc endpoints) can be used for traces
module "this" {
  source = "../.."
  # source  = "dasmeta/eks/aws"
  # version = ">= 2.20.0"

  # commons resources configs
  cluster_name = local.cluster_name

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    "default" = {
      "min_size"     = 1,
      "desired_size" = 3,
      "max_size"     = 3
    }
  }
  node_groups_default = {
    "capacity_type"  = "SPOT",
    "instance_types" = ["t3.medium"]
  }

  # disabled resources for this test to have as minimal sized cluster as possible
  alarms = {
    enabled   = false
    sns_topic = ""
  }
  enable_external_secrets      = false
  create_cert_manager          = false
  enable_node_problem_detector = false
  autoscaling                  = false

  karpenter = {
    enabled = false
  }

  linkerd = {
    enabled = false
  }

  keda = {
    enabled = false
  }

  # enabled resources for this test
  enable_ebs_driver = true
  default_addons = {
    coredns = {
      most_recent = true
      configuration_values = { # can be here we have defaults for replica count, resource request/limits and corefile config file, in case there are dns resolve issues on high load websites check to increase limits
        replicaCount = 1
        resources = {
          limits = {
            memory = "171Mi"
          }
          requests = {
            cpu    = "30m"
            memory = "30Mi"
          }
        }
        # this is main coredns config file and in case you get domain name resolution errors check ttl and max_concurrent values, NOTE: that for example increasing max_concurrent value requires also increase to memory 2kb per connection, check docs here: https://coredns.io/plugins/forward/
        corefile = <<EOT
        .:53 {
            errors
            health {
                lameduck 5s
              }
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
              ttl 120
            }
            prometheus :9153
            forward . /etc/resolv.conf {
              max_concurrent 2000
            }
            cache 30
            loop
            reload
            loadbalance
        }
        EOT
      }
    }
  }
  nginx_ingress_controller_config = {
    enabled = true

    replicacount = 1
  }

  alb_load_balancer_controller = {
    configs = {
      replicaCount = 1
    }
  }

  external_dns = {
    enabled = true
    configs = {
      configs = { sources = ["service", "ingress"] }
    }
  }

  # The common configs for this example, NOTE: with new versions(>= 2.23.0) of module this should be set already
  metrics_exporter = "none" # we disable metric exporter(adot and cloudwatch) as we will have have metrics collected by prometheus
  fluent_bit_configs = {    # we disable fluentbit as we will have logs collected by loki-promtail
    enabled = false
  }
}

# deploy an test app
resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.13"
  wait       = true

  values = [file("${path.module}/http-echo-eks-with-all-telemetry-to-grafana-stack.yaml")]

  depends_on = [module.this]
}

# deploy grafana stack which will collect metrics/logs into prometheus/loki and allow to explore them in grafana dashboards
module "grafana_monitoring" {
  source  = "dasmeta/grafana/onpremise"
  version = "1.18.1"

  name         = "eks-logs-metrics-traces-to-grafana-stack"
  cluster_name = local.cluster_name

  application_dashboard = {
    data_source = {
      uid = "prometheus"
    }
    rows : [
      { type : "block/sla", sla_ingress_type = "nginx" },
      { type : "block/ingress" },
      { type : "block/service", name = "http-echo" }
    ]
    variables = [
      {
        "name" : "namespace",
        "options" : [
          {
            "value" : "default"
          }
        ]
      }
    ]
  }

  grafana_configs = {
    enabled = true

    resources = {
      request = {
        cpu = "64m"
        mem = "64Mi"
      }
    }
    ingress = {
      type        = "nginx"
      tls_enabled = false
      hosts       = ["grafana-eks-with-all-telemetry-to-grafana-stack.devops.dasmeta.com"]
    }
    datasources = [{ type = "cloudwatch", name = "Cloudwatch" }]
  }

  tempo_configs = {
    enabled         = true
    storage_backend = "local"
    cluster_name    = local.cluster_name

    metrics_generator = {
      enabled = true
    }
    enable_service_monitor = true

    persistence = {
      enabled = false
    }
  }

  loki_configs = {
    enabled = true
    promtail = { # the promtail is default/native log collector for loki, but in this example we will use fluentbit to push logs to loki
      enabled = true
    }
  }

  prometheus_configs = {
    enabled             = true
    enable_alertmanager = false
    replicas            = 1
    resources = {
      request = { cpu = "256m", mem = "256Mi" }
    }
    storage_size = "1Gi"
  }

  grafana_admin_password = "admin"
  aws_region             = local.aws_region

  depends_on = [module.this]
}
