# EKS with Istio Gateway API (TLS enabled)

This example demonstrates how to create an EKS cluster with Istio and Gateway API configured for a wildcard domain (`*.devops.dasmeta.com`) with both HTTP and HTTPS listeners, supporting both external (internet-facing) and internal LoadBalancers.

## Features

- **EKS Cluster**: Complete EKS cluster with all necessary components
- **Istio Integration**: Istio service mesh with Gateway API support
- **Domains**: `external.devops.dasmeta.com`/`internal.devops.dasmeta.com` - supports external/internal subdomains under `devops.dasmeta.com`
- **Dual Gateway Setup**:
  - **External Gateway** (`main`): Internet-facing AWS Network Load Balancer for public access
  - **Internal Gateway** (`main-internal`): Internal AWS Network Load Balancer for VPC-only access
- **HTTP Listener**: Port 80 for HTTP traffic on both Gateways
- **HTTPS Listener**: Port 443 with TLS certificate managed by cert-manager on both Gateways
- **Automatic HTTP to HTTPS Redirect**: HTTPRoute resources automatically redirect all HTTP traffic to HTTPS (301 redirect)
- **Certificate Management**: Uses cert-manager with `letsencrypt-prod` ClusterIssuer for automatic certificate provisioning
- **Certificate**: Each Gateways use its own TLS certificate Secret(but if both use same domains/wildcard the certificate secret can be shared)

## Prerequisites

1. **AWS Account** with appropriate permissions to create EKS clusters
2. **Existing VPC** with subnets (the example uses the default VPC)
3. **cert-manager** installed in the cluster (enabled via `create_cert_manager = true`)
4. **ClusterIssuer** configured via `cert_manager_cluster_issuer` variable

### ClusterIssuer Configuration

The example includes a `cert_manager_cluster_issuer` configuration that creates a Let's Encrypt ClusterIssuer with DNS01 challenge support.

**DNS01 Configuration**:
- Configured in the example for Route53
- Requires AWS credentials (IRSA, static credentials, etc.)
- Works for domains (`external/internal.devops.dasmeta.com`)

**HTTP01 Configuration** (optional, for exact domains only):
- Can be enabled by uncommenting the `http01` section in the example
- Supports Gateway API via `gateway_http_route` configuration
- References the external Gateway (`main`) for internet access
- Does NOT work for wildcard domains

**Example Configuration:**
```hcl
cert_manager_cluster_issuer = {
  enabled = true
  name    = "letsencrypt-prod"
  email   = "admin@example.com"
  dns01 = {
    enabled = true
    configs = {
      route53 = {
        region = "eu-central-1"
        # Configure accessKeyID and secretAccessKeySecretRef based on your setup
      }
    }
  }
  # Optional: HTTP01 for exact domains
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
```

## Configuration

### External Gateway (`main`)
- Gateway name: `main`
- Gateway class: `istio`
- Namespace: `istio-system` (default)
- HTTP listener on port 80
- HTTPS listener on port 443 with TLS configuration pointing to cert-manager
- AWS NLB: Internet-facing Network Load Balancer
  - `service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"`
  - `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"`
  - `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"`

### Internal Gateway (`main-internal`)
- Gateway name: `main-internal`
- Gateway class: `istio`
- Namespace: `istio-system` (default)
- HTTP listener on port 80
- HTTPS listener on port 443 with TLS configuration pointing to cert-manager
- AWS NLB: Internal Network Load Balancer (VPC-only access)
  - `service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"`
  - `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"`
  - `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"`


### HTTP to HTTPS Redirect

The example includes HTTPRoute resources that automatically redirect all HTTP traffic to HTTPS:

- **External Gateway Redirect**: `http-to-https-redirect-external` - redirects HTTP traffic on the external Gateway
- **Internal Gateway Redirect**: `http-to-https-redirect-internal` - redirects HTTP traffic on the internal Gateway

Both redirects:
- Match all hostnames: `*.devops.dasmeta.com`
- Reference the HTTP listener (`sectionName: "http-80"`) on their respective Gateways
- Use a 301 (Permanent Redirect) status code
- Redirect to HTTPS scheme

**Important Notes:**
- The redirects do **not** interfere with HTTP01 ACME challenges because:
  - cert-manager creates HTTPRoutes with specific path matches (`/.well-known/acme-challenge/*`)
  - Gateway API matches the most specific route first
  - cert-manager's HTTPRoutes will take precedence over the redirect for ACME challenge paths
- The HTTP listener (port 80) is still required for:
  - HTTP01 ACME challenges (if using HTTP01 resolver)
  - Initial HTTP requests that will be redirected to HTTPS

## Certificate Management

The HTTPS listener uses cert-manager to automatically provision and renew TLS certificates:
- Certificate name: `{gateway-name}-tls`
- ClusterIssuer: `letsencrypt-prod`
- DNS names: `*.devops.dasmeta.com`, `devops.dasmeta.com`

### How Gateway API Interacts with Certificates

**Important**: The Gateway API Gateway resource **only reads** the TLS certificate Secret - it does **not modify** it.

- **Existing Secrets**: If a Secret with the certificate already exists, the Gateway will use it without modification
- **Secret Management**: The Secret is managed entirely by cert-manager (via the Certificate resource)
- **Gateway Role**: The Gateway simply references the Secret via `certificateRefs` and reads the certificate data from it

### Certificate Rotation

Certificate rotation is handled **entirely by cert-manager** - Gateway API is **not involved** in the rotation process.

**How it works:**
1. **Initial Provisioning**: cert-manager creates the Certificate resource, which triggers the `letsencrypt-prod` ClusterIssuer
2. **Challenge Validation**: The ClusterIssuer uses either DNS01 or HTTP01 resolver to prove domain ownership:

   **DNS01 Challenge** (e.g., Route53, Cloudflare):
   - cert-manager creates DNS TXT records to prove domain ownership
   - No Gateway involvement required
   - Works for wildcard domains (`*.devops.dasmeta.com`)

   **HTTP01 Challenge**:
   - **Requires**: ClusterIssuer must be configured with `gatewayHTTPRoute` in the HTTP01 solver (see Prerequisites above)
   - cert-manager creates temporary HTTPRoute resources to serve challenge files
   - Challenge files are served at `http://<domain>/.well-known/acme-challenge/<token>`
   - **Requires**: Gateway must have an HTTP listener on port 80 (already configured in this example)
   - cert-manager automatically creates HTTPRoutes that route `/.well-known/acme-challenge/*` to cert-manager's solver service
   - The HTTPRoutes reference the Gateway via `parentRefs` (configured in ClusterIssuer)
   - The Gateway routes these HTTPRoutes normally - no special configuration needed
   - **Note**: HTTP01 does NOT work for wildcard domains - only exact domain matches

3. **Automatic Renewal**: cert-manager automatically monitors certificate expiration and renews certificates before they expire (typically 30 days before expiration)
4. **Secret Updates**: When cert-manager renews a certificate, it updates the Secret with the new certificate data
5. **Gateway Pickup**: The Gateway automatically picks up the new certificate from the updated Secret (no Gateway modification needed)

**Gateway API's Role**: The Gateway is a passive consumer of the Secret. It:
- Reads the certificate from the Secret when it starts
- Automatically reloads the certificate when the Secret is updated (Istio/Envoy watches the Secret)
- Does not participate in certificate creation, validation, or rotation
- For HTTP01: Routes HTTP traffic normally, including temporary challenge HTTPRoutes created by cert-manager

## Usage

After applying this configuration:
1. **Ensure ClusterIssuer is configured for Gateway API** (if using HTTP01):
   - The ClusterIssuer must have `gatewayHTTPRoute` configured in the HTTP01 solver
   - See "ClusterIssuer Configuration for Gateway API" section above
2. cert-manager will automatically create a Certificate resource
3. The Certificate will be validated by the `letsencrypt-prod` ClusterIssuer:
   - **DNS01**: cert-manager creates DNS TXT records (no Gateway involvement)
   - **HTTP01**: cert-manager creates temporary HTTPRoutes for `/.well-known/acme-challenge/*` (Gateway routes them normally)
4. Once validated, the certificate will be stored in the Secret `{gateway-name}-tls`
5. The Gateway will read the certificate from the Secret and use it for TLS termination
6. HTTPS traffic will be encrypted using the Let's Encrypt certificate
7. cert-manager will automatically renew the certificate before expiration (no Gateway changes needed)

**Important Notes:**
- **Wildcard domains** (`*.devops.dasmeta.com`) require **DNS01** resolver - HTTP01 does not support wildcards
- **HTTP01** requires:
  - Gateway to have an HTTP listener on port 80 (already configured)
  - ClusterIssuer configured with `gatewayHTTPRoute` in HTTP01 solver (see Prerequisites)
- For HTTP01, cert-manager automatically creates temporary HTTPRoutes - you don't need to create them manually
- The Gateway doesn't need special configuration for HTTP01 - it just routes HTTP traffic normally
- **Without `gatewayHTTPRoute` configuration**, cert-manager will default to creating Ingress resources, which won't work with Gateway API

## Example HTTPRoute

You can create HTTPRoute resources in any namespace that reference either Gateway:

### External Gateway Example

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-external
  namespace: my-namespace
spec:
  parentRefs:
    - name: main
      namespace: istio-system
  hostnames:
    - my-app.devops.dasmeta.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app-service
          port: 80
```

### Internal Gateway Example

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-internal
  namespace: my-namespace
spec:
  parentRefs:
    - name: main-internal
      namespace: istio-system
  hostnames:
    - my-app.devops.dasmeta.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app-service
          port: 80
```

**Note**: You can create HTTPRoutes that reference both Gateways if you want the same service accessible via both external and internal LoadBalancers.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31, < 6.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dns_parent_delegation"></a> [dns\_parent\_delegation](#module\_dns\_parent\_delegation) | dasmeta/dns/aws | 1.0.5 |
| <a name="module_dns_private"></a> [dns\_private](#module\_dns\_private) | dasmeta/dns/aws | 1.0.5 |
| <a name="module_dns_public"></a> [dns\_public](#module\_dns\_public) | dasmeta/dns/aws | 1.0.5 |
| <a name="module_this"></a> [this](#module\_this) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.http_echo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.http_echo_internal](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpcs.ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | Domain name for DNS zones and Gateway API configuration | `string` | `"istio.devops.dasmeta.com"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
