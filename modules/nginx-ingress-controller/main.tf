resource "helm_release" "ingress-nginx" {
  name             = var.name
  repository       = "https://kubernetes.github.io/ingress-nginx"
  values           = [jsonencode(module.custom_default_configs_merged.merged)]
  chart            = "ingress-nginx"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
}


module "custom_default_configs_merged" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
    {
      controller = {
        config = {
          use-forwarded-headers         = "true"
          enable-underscores-in-headers = "true"
        }
        replicaCount = var.replicacount
        metrics = {
          enabled : var.metrics_enabled
        }
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
          }
          internal = {
            annotations = {
              "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
            }
          }
        }
      }
    },
    var.metrics_enabled ? {
      controller = {
        podAnnotations = {
          "prometheus.io/scrape" = true
          "prometheus.io/port"   = 10254
        }
      }
    } : {},
    var.configs
  ]
}
