# Example: EKS with Istio Gateway API (TLS enabled)
#
# This configuration:
# - Creates an EKS cluster
# - Installs Istio with Gateway API CRDs
# - Creates two Gateways for the domain external.${var.domain} and internal.${var.domain}:
#   - "main": External Gateway (internet-facing AWS NLB)
#   - "main-internal": Internal Gateway (internal AWS NLB)
# - Both Gateways configure HTTP listener on port 80
# - Both Gateways configure HTTPS listener on port 443 with cert-manager integration
# - Uses letsencrypt-prod ClusterIssuer for automatic certificate provisioning
# - Each Gateways uses its own TLS certificate Secret
# - Automatically redirects all HTTP traffic to HTTPS via HTTPRoute resources

module "this" {
  source = "../.."

  cluster_name = "test-with-istio"

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
    }
  }
  node_groups_default = {
    capacity_type  = "SPOT",
    instance_types = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
  }

  alarms = {
    enabled   = false
    sns_topic = ""
  }
  enable_ebs_driver            = false
  enable_external_secrets      = false
  create_cert_manager          = true # Required for cert-manager ClusterIssuer
  enable_node_problem_detector = false
  metrics_exporter             = "disabled"
  fluent_bit_configs = {
    enabled = false
  }
  keda = {
    enabled = false
  }
  kyverno = {
    enabled = false
  }

  # Disable linkerd as we're using Istio
  linkerd = {
    enabled = false
  }

  # NOTE: by default aws has ability to handle LoadBalancer type services(which gateway objects create) without aws load balancer controller, but this is legacy mode and we do enable aws-loadbalancer-controller to use it
  alb_load_balancer_controller = {
    enabled = true # enabled by default but we explicitly enable it here
  }

  default_addons = {
    coredns = {
      configuration_values = {
        replicaCount = 1
      }
    }
  }

  # enable external-dns to automatically create R53 records based on gateway/httpRoute domain/host configs
  external_dns = {
    enabled = true
  }

  karpenter = {
    enabled = true
    configs = {
      replicas = 1
    }
    resource_configs = {
      nodePools = {
        general = {
          template = {
            spec = {
              requirements = [
                {
                  key      = "topology.kubernetes.io/zone"
                  operator = "In"
                  values   = ["eu-central-1a"] # pin the test setup nodes to a specific zone
                }
              ]
            }
          }
        }
      }
    }
  }

  # Enable cert-manager resources (ClusterIssuers and Certificates)
  cert_manager = {
    extra_configs = {
      # NOTE: we set this extra options only to overcome the private zone related issues as when we have both private and public zones the DNS01 solver waits to have dns record on private zone also but txt record for challenge being created in public zone only and cert-manager controller from k8s cluster sees only private zone when it asks for dns records
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=1.1.1.1:53",
      ]
      config = {
        enableGatewayAPI = true # enable Gateway API resources handling by cert-manager
      }
    }
    resources = {
      # ClusterIssuer configuration - supports multiple issuers
      cluster_issuers = [
        {
          name  = "letsencrypt-prod"
          email = "support@dasmeta.com"
          dns01 = {
            enabled = true
            # Route53 configuration with IRSA (recommended)
            configs = {
              route53 = {}
            }
          }
        }
      ]
    }
  }

  # Enable Istio with Gateway API configuration
  # NOTE: AWS Load Balancer Controller handles LoadBalancer creation for all LoadBalancer services
  # (including istio-gateway and Gateway API Gateways)
  istio = {
    enabled = true
    configs = {
      gateway = {
        # Enable Gateway API resources (native k8s Gateway objects)
        api_resources = {
          gateways = [
            # External Gateway (internet-facing AWS NLB)
            {
              name             = "main"
              gatewayClassName = "istio"
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-prod" # for handling certificate requests automatically by cert-manager controller
              }
              listeners = [
                # HTTP listener on port 80
                {
                  name     = "http-80"
                  hostname = "external.${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                },
                # HTTPS listener on port 443 with TLS(the tls being set automatically for https)
                {
                  name     = "https-443"
                  hostname = "external.${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                }
              ]
              # AWS NLB infrastructure configuration for external LoadBalancer
              infrastructure = {
                annotations = {
                  "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
                  "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
                  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"

                  ## attaching custom security groups to the NLB for restricting access to the NLB
                  ## NOTE: this can be enabled to restrict access to the external NLB to allowed IP only
                  # "service.beta.kubernetes.io/aws-load-balancer-security-groups"                     = aws_security_group.nlb_restricted.id
                  # "service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules" = "true" # needed for load balancer to backend services access
                  # "service.beta.kubernetes.io/aws-load-balancer-extra-security-groups" = aws_security_group.nlb_restricted.id # for only AWS Cloud Provider attaching custom security groups to the classic load balancer(not working with NLB) for restricting access to the NLB(works with only Service Controller in the AWS Cloud Provider (legacy))
                }
                # can be used to customize the gateway proxy pods template
                # parameters = {
                #   deployment = {
                #     spec = {
                #       replicas = 2
                #     }
                #   }
                # }
              }
            },
            # Internal Gateway (internal AWS NLB)
            {
              name             = "main-internal"
              gatewayClassName = "istio"
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-prod" # set cert-manager cluster issuer for the gateway to handle certificate requests provisioning
              }
              listeners = [
                # HTTP listener on port 80
                {
                  name     = "http-80"
                  hostname = "internal.${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                },
                # HTTPS listener on port 443 with TLS(the tls being set automatically for https)
                {
                  name     = "https-443"
                  hostname = "internal.${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                }
              ]
              # AWS NLB infrastructure configuration for internal LoadBalancer
              infrastructure = {
                annotations = {
                  "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
                  # "service.beta.kubernetes.io/aws-load-balancer-internal" = "true" # being used to have internal load balancer (works with only Service Controller in the AWS Cloud Provider (legacy))
                  "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
                  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
                }
              }
            }
          ]
          # HTTP to HTTPS redirect for both Gateways
          # This creates HTTPRoute resources that automatically redirect all HTTP traffic to HTTPS
          httpRoutes = [
            # HTTP to HTTPS redirect for external Gateway
            {
              name = "http-to-https-redirect-external"
              parentRefs = [
                {
                  name        = "main"
                  sectionName = "http-80"
                }
              ]
              hostnames = ["external.${var.domain}"]
              rules = [
                {
                  redirect = {
                    scheme     = "https"
                    statusCode = 301
                  }
                }
              ]
            },
            # HTTP to HTTPS redirect for internal Gateway
            {
              name = "http-to-https-redirect-internal"
              parentRefs = [
                {
                  name        = "main-internal"
                  sectionName = "http-80"
                }
              ]
              hostnames = ["internal.${var.domain}"]
              rules = [
                {
                  redirect = {
                    scheme     = "https"
                    statusCode = 301
                  }
                }
              ]
            }
          ]
        }
      }
      # Istiod configuration - disable automatic sidecar injection
      istiod = {
        configs = {
          # Disable automatic sidecar injection globally
          # This prevents Istio from injecting sidecars into pods (horizontal service mesh)
          global = {
            proxy = {
              autoInject = "disabled"
            }
          }
          # autoscaleMin = 2 # for redundancy we can have more than 1 replica of istiod controller
        }
      }
    }
  }
}

# Base chart with Gateway API enabled
# This deploys an http-echo service with Gateway API HTTPRoute configuration
resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.24"
  wait       = true

  values = [templatefile("${path.module}/http-echo.yaml", { domain = var.domain })]

  depends_on = [module.this]
}

# Base chart with Gateway API enabled for internal gateway
# This deploys an http-echo service with Gateway API HTTPRoute configuration
# HTTPRoute routes all traffic (including /admin) to the service via internal gateway
# Reuses http-echo.yaml and overrides only the necessary fields
resource "helm_release" "http_echo_internal" {
  name       = "http-echo-internal"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.24"
  wait       = true

  values = [
    templatefile("${path.module}/http-echo.yaml", { domain = var.domain }),
    templatefile("${path.module}/http-echo-internal.yaml", { domain = var.domain }),
  ]

  depends_on = [module.this]
}
