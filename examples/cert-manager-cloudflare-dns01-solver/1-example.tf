# Example: EKS with cert-manager and Cloudflare DNS01 solver
#
# This configuration:
# - Creates an EKS cluster with cert-manager enabled
# - Creates a ClusterIssuer that uses Cloudflare for DNS01 challenges (e.g. wildcard certs)
# - Creates the API token secret via cert_manager.resources.cluster_issuers[].dns01.secrets
#   so you do not need to create the secret separately
#
# Prerequisites:
# - Cloudflare API token with "Edit zone DNS" permission for your zone
# - Set TF_VAR_cloudflare_api_token or pass -var="cloudflare_api_token=..."

module "this" {
  source = "../.."

  cluster_name = "test-cert-manager-cloudflare"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    default = {
      desired_size = 1
      max_size     = 1
      min_size     = 1
    }
  }

  node_groups_default = {
    capacity_type  = "SPOT"
    instance_types = ["t3.medium"]
  }

  alarms = {
    enabled   = false
    sns_topic = ""
  }

  create_cert_manager     = true
  metrics_exporter        = "disabled"
  enable_ebs_driver       = false
  enable_external_secrets = false

  fluent_bit_configs = { enabled = false }
  keda               = { enabled = false }
  kyverno            = { enabled = false }
  linkerd            = { enabled = false }
  karpenter          = { enabled = false }

  cert_manager = {
    resources = {
      # Secret data keyed by "${issuer.name}/${secret_ref.name}" so for_each is not sensitive.
      dns01_secret_data = {
        "letsencrypt-prod/cloudflare-api" = {
          "api-token" = var.cloudflare_api_token
        }
      }

      cluster_issuers = [
        {
          name  = "letsencrypt-prod"
          email = "support@${var.domain}"

          dns01 = {
            enabled = true

            # Names only (no sensitive data here). Data is in dns01_secret_data above.
            secret_refs = [{ name = "cloudflare-api" }]

            # Cloudflare DNS01 solver config: reference the secret created from secret_refs + dns01_secret_data.
            configs = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = "letsencrypt-prod-cloudflare-api"
                  key  = "api-token"
                }
              }
            }
          }
        }
      ]

      # Optional: request a certificate for var.domain (zone must be in Cloudflare).
      certificates = [
        {
          name        = "${replace(var.domain, ".", "-")}-tls"
          namespace   = "default"
          secret_name = "${replace(var.domain, ".", "-")}-tls"
          issuer_ref = {
            name = "letsencrypt-prod"
            kind = "ClusterIssuer"
          }
          dns_names = [var.domain, "*.${var.domain}"]
        }
      ]
    }
  }
}
