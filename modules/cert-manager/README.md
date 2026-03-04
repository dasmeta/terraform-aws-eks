# cert-manager Module

This module installs cert-manager Helm chart and creates cert-manager resources (ClusterIssuer and Certificate) for Let's Encrypt with support for DNS01 and HTTP01 challenge solvers.

## Features

- **Helm Chart Installation**: Installs cert-manager Helm chart with CRDs
- **Let's Encrypt Integration**: Creates a ClusterIssuer for Let's Encrypt (production or staging)
- **DNS01 Challenge**: Support for DNS-based challenge validation (Route53, Cloudflare, etc.)
  - **IRSA Support**: Automatic IAM role and service account annotation for Route53 (recommended)
  - **Static Credentials**: Support for static AWS credentials via Secrets (not recommended)
- **HTTP01 Challenge**: Support for HTTP-based challenge validation
  - **Gateway API**: HTTP01 via Gateway API HTTPRoute resources
  - **Ingress**: HTTP01 via traditional Kubernetes Ingress resources
- **Certificate Management**: Creates `cert-manager.io/v1` Certificate resources
- **Flexible Configuration**: Supports both production and staging Let's Encrypt servers

## Usage

### Basic Example

```hcl
module "cert-manager" {
  source = "./modules/cert-manager"

  chart_version = "1.16.2"
  namespace     = "cert-manager"

  cluster_name      = "my-eks-cluster"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.region.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"

  cluster_issuer = {
    name  = "letsencrypt-prod"
    email = "admin@example.com"
    dns01 = {
      enabled = true
      configs = {
        route53 = {
          region = "eu-central-1"
        }
      }
      iam_role = {
        enabled = true
        service_account_name = "cert-manager"
        namespace            = "cert-manager"
      }
    }
  }

  certificates = [
    {
      name        = "my-app-tls"
      namespace   = "my-app-namespace"
      secret_name = "my-app-tls-secret"
      issuer_ref = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dns_names = [
        "my-app.example.com",
        "www.my-app.example.com"
      ]
    }
  ]

  depends_on_resources = [module.eks-core-components-and-alb]
}
```

## Inputs

| Name                 | Description                                                | Type           | Default          | Required |
| -------------------- | ---------------------------------------------------------- | -------------- | ---------------- | -------- |
| chart_version        | The cert-manager helm chart version                        | `string`       | `"1.16.2"`       | no       |
| namespace            | Namespace where cert-manager will be installed             | `string`       | `"cert-manager"` | no       |
| create_namespace     | Whether to create the namespace                            | `bool`         | `true`           | no       |
| atomic               | Whether to auto rollback if helm install fails             | `bool`         | `true`           | no       |
| cluster_name         | EKS cluster name for IAM role naming and IRSA trust policy | `string`       | n/a              | yes      |
| oidc_provider_arn    | EKS OIDC provider ARN for IAM role trust policy            | `string`       | n/a              | yes      |
| cluster_issuer       | Configuration for the cert-manager ClusterIssuer           | `object`       | `{}`             | no       |
| certificates         | List of Certificate resources to create                    | `list(object)` | `[]`             | no       |
| depends_on_resources | List of resources that cert-manager Helm chart depends on  | `any`          | `[]`             | no       |

## Outputs

| Name                   | Description                                        |
| ---------------------- | -------------------------------------------------- |
| helm_release_name      | Name of the cert-manager Helm release              |
| helm_release_namespace | Namespace of the cert-manager Helm release         |
| cluster_issuer_name    | Name of the created ClusterIssuer resource         |
| iam_role_arn           | ARN of the IAM role created for DNS01 (if enabled) |
| certificate_names      | Map of certificate names by namespace/name         |

## Notes

- **Helm Chart**: The cert-manager Helm chart is installed with `installCRDs=true` to automatically install Custom Resource Definitions
- **IAM Role**: For DNS01 with Route53, IRSA is recommended - the module automatically creates an IAM role and annotates the cert-manager service account
- **ClusterIssuer**: Only created if `cluster_issuer.name` is provided
- **Certificates**: Certificate resources are created using `kubectl_manifest` and depend on the ClusterIssuer
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31, < 6.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 1.14 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dns01_role"></a> [dns01\_role](#module\_dns01\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.28.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.dns01_route53](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [helm_release.cert-manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.certificate](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.cluster_issuer](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.dns01_solver_secret](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether to auto rollback if helm install fails | `bool` | `true` | no |
| <a name="input_certificates"></a> [certificates](#input\_certificates) | List of Certificate resources to create. Each object defines a cert-manager.io/v1 Certificate. | <pre>list(object({<br/>    name        = string<br/>    namespace   = optional(string, "istio-system")<br/>    secret_name = optional(string, null) # Optional: Kubernetes secret name for the issued cert; default is certificate name<br/>    issuer_ref = object({<br/>      name  = string<br/>      kind  = optional(string, "ClusterIssuer")<br/>      group = optional(string, "cert-manager.io")<br/>    })<br/>    dns_names    = optional(list(string), [])<br/>    common_name  = optional(string, null)<br/>    duration     = optional(string, null)     # e.g., "2160h" (90 days)<br/>    renew_before = optional(string, null)     # e.g., "360h" (15 days)<br/>    usages       = optional(list(string), []) # e.g., ["server auth", "client auth"]<br/>    configs      = optional(any, {})          # Extra configs to merge into the Certificate spec<br/>  }))</pre> | `[]` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The cert-manager helm chart version | `string` | `"1.16.5"` | no |
| <a name="input_cluster_issuers"></a> [cluster\_issuers](#input\_cluster\_issuers) | List of ClusterIssuer configurations. Supports multiple issuers. Each issuer supports DNS01 and HTTP01 challenge solvers. For HTTP01, can use Gateway API (gateway\_http\_route) or traditional Ingress (ingress). | <pre>list(object({<br/>    name                    = optional(string, "letsencrypt-prod")                               # Name of the ClusterIssuer resource<br/>    email                   = optional(string, "support@dasmeta.com")                            # Required - email for Let's Encrypt account registration<br/>    server                  = optional(string, "https://acme-v02.api.letsencrypt.org/directory") # ACME server URL<br/>    private_key_secret_name = optional(string, null)                                             # Optional: custom secret name for private key, defaults to cluster_issuer.name<br/>    # For Route53 in the same AWS account we create the IAM role (iam_role below). For other providers (e.g. Cloudflare) use secret_refs + dns01_secret_data and configs.<br/>    dns01 = optional(object({<br/>      enabled = optional(bool, false) # Enable DNS01 challenge solver<br/>      configs = optional(any, {})     # DNS01 solver configuration (e.g., secretRef for Cloudflare: apiTokenSecretRef.name = "${issuer.name}-<secret.name>")<br/>      # Optional: create Kubernetes secrets for the solver. List only names here (no sensitive data). Pass actual data via the separate dns01_secret_data variable. Created secret name = "${issuer.name}-${ref.name}".<br/>      secret_refs = optional(list(object({<br/>        name = string # Final secret name will be "${cluster_issuer.name}-${name}"<br/>      })), [])<br/>      iam_role = optional(object({<br/>        enabled          = optional(bool, true)       # Enable IAM role for DNS01 (IRSA) - uses cert-manager service account from Helm chart<br/>        hosted_zone_arns = optional(list(string), []) # Optional: restrict to specific hosted zones, empty list = all zones<br/>      }), {})<br/>    }), null)<br/>    http01 = optional(object({<br/>      enabled = optional(bool, false) # Enable HTTP01 challenge solver<br/>      gateway_http_route = optional(object({<br/>        parent_refs = optional(list(object({<br/>          name      = string                                        # Gateway name<br/>          namespace = optional(string, "istio-system")              # Gateway namespace<br/>          kind      = optional(string, "Gateway")                   # Gateway kind<br/>          group     = optional(string, "gateway.networking.k8s.io") # Gateway API group<br/>        })), [])<br/>      }), null) # Gateway API HTTP01 configuration<br/>      ingress = optional(object({<br/>        class = optional(string, "nginx") # Ingress class for HTTP01<br/>      }), null)                           # Traditional Ingress HTTP01 configuration<br/>    }), null)<br/>  }))</pre> | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name for IAM role naming and IRSA trust policy | `string` | n/a | yes |
| <a name="input_configs"></a> [configs](#input\_configs) | Default Helm values to merge with the default cert-manager chart values | <pre>object({<br/>    installCRDs = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the namespace | `bool` | `true` | no |
| <a name="input_dns01_secret_data"></a> [dns01\_secret\_data](#input\_dns01\_secret\_data) | Map of DNS01 secret data keyed by issuer name + secret name (e.g. "letsencrypt-prod/cloudflare-api"). Keeps sensitive data out of for\_each. | `map(map(string))` | `{}` | no |
| <a name="input_extra_configs"></a> [extra\_configs](#input\_extra\_configs) | Extra Helm values to merge with the default cert-manager chart values (e.g., controller config, webhook config) | `any` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace where cert-manager will be installed | `string` | `"cert-manager"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKS OIDC provider ARN for IAM role trust policy | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_names"></a> [certificate\_names](#output\_certificate\_names) | Map of certificate names by namespace/name |
| <a name="output_cluster_issuer_names"></a> [cluster\_issuer\_names](#output\_cluster\_issuer\_names) | Map of ClusterIssuer names by issuer name |
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the cert-manager Helm release |
| <a name="output_helm_release_namespace"></a> [helm\_release\_namespace](#output\_helm\_release\_namespace) | Namespace of the cert-manager Helm release |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role created for DNS01 (shared by all issuers, if enabled) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
