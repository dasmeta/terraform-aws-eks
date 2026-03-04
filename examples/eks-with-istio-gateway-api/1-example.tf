# Example: EKS with Istio Gateway API (Wildcard Domain and TLS)
#
# This configuration:
# - Creates an EKS cluster
# - Installs Istio with Gateway API CRDs
# - Creates two Gateways for the same wildcard domain *.${var.domain}:
#   - "main": External Gateway (internet-facing AWS NLB)
#   - "main-internal": Internal Gateway (internal AWS NLB)
# - Both Gateways configure HTTP listener on port 80
# - Both Gateways configure HTTPS listener on port 443 with cert-manager integration
# - Uses letsencrypt-prod ClusterIssuer for automatic certificate provisioning
# - Both Gateways share the same TLS certificate Secret
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
    instance_types = ["t3.medium", "t3a.medium", "t3.small", "t3a.small", "t3.xlarge", "t3a.xlarge", "t3.large", "t3a.large"]
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
      dns01RecursiveNameservers     = "1.1.1.1:53,8.8.8.8:53" # we set this dns01Recursive* options to overcome the private zone related issues as when we have both private and public zones the DNS01 solver waits to have dns record on private zone also but txt the record for challenge nge being created in public zone only
      dns01RecursiveNameserversOnly = true
    }
    resources = {
      # ClusterIssuer configuration - supports multiple issuers
      cluster_issuers = [
        {
          name  = "letsencrypt-prod"
          email = "support@dasmeta.com"
          # DNS01 configuration (required for wildcard domains)
          dns01 = {
            enabled = true
            # Route53 configuration with IRSA (recommended)
            configs = {
              route53 = {
                region = "eu-central-1"
                # When using IRSA, accessKeyID and secretAccessKeySecretRef are not needed
                # The IAM role will be automatically used via the service account annotation
              }
            }
          }
          # HTTP01 configuration (optional, for exact domains only)
          # Uncomment and configure if you want to use HTTP01 for non-wildcard domains
          # http01 = {
          #   enabled = true
          #   gateway_http_route = {
          #     parent_refs = [
          #       {
          #         name      = "main"
          #         namespace = "istio-system"
          #       }
          #     ]
          #   }
          # }
        }
        # Add more ClusterIssuers here if needed, e.g.:
        # {
        #   name  = "letsencrypt-staging"
        #   email = "support@dasmeta.com"
        #   server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        #   dns01 = { ... }
        # }
      ]
      # Certificate resources (optional)
      certificates = [
        {
          name        = "wildcard-istio-devops-dasmeta-com-tls"
          namespace   = "istio-system"
          secret_name = "wildcard-istio-devops-dasmeta-com-tls"
          issuer_ref = {
            name = "letsencrypt-prod"
            kind = "ClusterIssuer"
          }
          dns_names = [
            "*.${var.domain}",
            var.domain
          ]
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
              listeners = [
                # HTTP listener on port 80
                {
                  name     = "http-80"
                  hostname = "${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                },
                # HTTPS listener on port 443 with TLS
                {
                  name     = "https-443"
                  hostname = "${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                  tls = {
                    mode = "Terminate"
                    certificateRefs = [
                      {
                        name  = "wildcard-istio-devops-dasmeta-com-tls"
                        kind  = "Secret"
                        group = ""
                      }
                    ]
                  }
                },
                # HTTP listener on port 80
                {
                  name     = "http-80-wildcard"
                  hostname = "*.${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                },
                # HTTPS listener on port 443 with TLS
                {
                  name     = "https-443-wildcard"
                  hostname = "*.${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                  tls = {
                    mode = "Terminate"
                    certificateRefs = [
                      {
                        name  = "wildcard-istio-devops-dasmeta-com-tls"
                        kind  = "Secret"
                        group = ""
                      }
                    ]
                  }
                }
              ]
              # AWS NLB infrastructure configuration for external LoadBalancer
              infrastructure = {
                annotations = {
                  "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
                  "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
                  "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
                  ## attaching custom security groups to the NLB for restricting access to the NLB
                  ## NOTE: this can be enabled to restrict access to the external NLB to allowed IP only
                  # "service.beta.kubernetes.io/aws-load-balancer-security-groups"                     = aws_security_group.nlb_restricted.id
                  # "service.beta.kubernetes.io/aws-load-balancer-manage-backend-security-group-rules" = "true" # needed for load balancer to backend services access
                }
              }
            },
            # Internal Gateway (internal AWS NLB)
            {
              name             = "main-internal"
              gatewayClassName = "istio"
              listeners = [
                # HTTP listener on port 80
                {
                  name     = "http-80"
                  hostname = "${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                },
                # HTTPS listener on port 443 with TLS
                {
                  name     = "https-443"
                  hostname = "${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                  tls = {
                    mode = "Terminate"
                    certificateRefs = [
                      {
                        name  = "wildcard-istio-devops-dasmeta-com-tls"
                        kind  = "Secret"
                        group = ""
                      }
                    ]
                  }
                },
                # HTTP listener on port 80 wildcard
                {
                  name     = "http-80-wildcard"
                  hostname = "*.${var.domain}"
                  port     = 80
                  protocol = "HTTP"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                },
                # HTTPS listener on port 443 with TLS wildcard
                {
                  name     = "https-443-wildcard"
                  hostname = "*.${var.domain}"
                  port     = 443
                  protocol = "HTTPS"
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                  tls = {
                    mode = "Terminate"
                    certificateRefs = [
                      {
                        name  = "wildcard-istio-devops-dasmeta-com-tls"
                        kind  = "Secret"
                        group = ""
                      }
                    ]
                  }
                }
              ]
              # AWS NLB infrastructure configuration for internal LoadBalancer
              infrastructure = {
                annotations = {
                  "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
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
                },
                {
                  name        = "main"
                  sectionName = "https-80-wildcard"
                }
              ]
              hostnames = ["${var.domain}", "*.${var.domain}"]
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
                },
                {
                  name        = "main-internal"
                  sectionName = "https-80-wildcard"
                }
              ]
              hostnames = ["${var.domain}", "*.${var.domain}"]
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
  version    = "0.3.21"
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
  version    = "0.3.21"
  wait       = true

  values = [
    templatefile("${path.module}/http-echo.yaml", { domain = var.domain }),
    templatefile("${path.module}/http-echo-internal.yaml", { domain = var.domain }),
  ]

  depends_on = [module.this]
}
