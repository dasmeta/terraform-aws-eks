# external-secrets (controller)

Installs the [external-secrets](https://external-secrets.io/) controller via Helm and
provisions the AWS identity it runs as.

Adapted from the upstream dasmeta module:

- **Configurable chart source** — `chart.name` accepts either a chart name (resolved against
  `chart.repository`) or a full `https://…/*.tgz` URL (a direct compressed endpoint, e.g. an
  privately-hosted archive); when a URL is given, repository/version are ignored.
- **Image overrides** — `image.{registry,repository,tag}` override the controller / webhook /
  cert-controller images (e.g. to a private registry mirror). Unset ⇒ chart defaults.
- **Extra values** — `values` and `extra_values` are merged into the release (extras last).
- **Modern AWS identity** — the controller service account gets its IAM role via an EKS
  **Pod Identity association** (default) or **IRSA** (`attachment_method =
  "service_account_role_annotation"`). The base role carries no Secrets Manager access; it
  may only `sts:AssumeRole` the per-store roles (`role/<store_role_name_prefix>*`). No IAM
  users or static access keys are created.

The direct `terraform-module/release/helm` wrapper and static-credential handling from the
upstream module have been replaced by a direct `helm_release` plus the IAM wiring above.

## Key inputs

| Name | Description | Default |
|------|-------------|---------|
| `cluster_name` | EKS cluster name (required). | — |
| `region` | Region (for the IRSA OIDC host). | `""` |
| `namespace` | Install namespace. | `kube-system` |
| `service_account_name` | Controller SA name. | `external-secrets` |
| `chart` | `{ name, repository, version }`. | chart `external-secrets` @ `2.8.0` |
| `image` | `{ registry, repository, tag }` overrides. | chart defaults |
| `attachment_method` | `pod_identity_association` / `service_account_role_annotation` / `null`. | `pod_identity_association` |
| `store_role_name_prefix` | Prefix of store roles the controller may assume. | `external-secrets-store-` |
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# external-secrets controller

Installs the external-secrets controller via Helm and provisions the AWS identity it runs
as (EKS Pod Identity association by default, IRSA optional). Static IAM users / access keys
are never created. The chart source supports both a standard Helm repo and a direct
compressed .tgz endpoint, and controller/webhook/cert-controller images can be overridden
to a private registry.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_pod_identity_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.assume_store_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | n/a | `bool` | `false` | no |
| <a name="input_attachment_method"></a> [attachment\_method](#input\_attachment\_method) | How the controller SA gets its IAM role: pod\_identity\_association, service\_account\_role\_annotation (IRSA), or null to manage the association externally. | `string` | `"pod_identity_association"` | no |
| <a name="input_chart"></a> [chart](#input\_chart) | Chart source: `name` holds EITHER a chart name (resolved against `repository`) OR a full https .tgz URL (a direct compressed endpoint, e.g. a privately-hosted archive). When a URL is given, `repository`/`version` are ignored (the archive is self-describing). | <pre>object({<br/>    name       = optional(string, "external-secrets")                   # chart name OR a full https .tgz URL (direct compressed endpoint)<br/>    repository = optional(string, "https://charts.external-secrets.io") # helm repo URL; ignored when `name` is a .tgz URL<br/>    version    = optional(string, "2.8.0")                              # chart version; ignored when `name` is a .tgz URL (2.8.0 ships the external-secrets.io/v1 API)<br/>  })</pre> | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name (used for the Pod Identity association and OIDC lookup). | `string` | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the namespace. | `bool` | `false` | no |
| <a name="input_extra_values"></a> [extra\_values](#input\_extra\_values) | Arbitrary extra Helm values merged last (highest precedence). | `any` | `{}` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Optional name override for the controller IAM role. Defaults to external-secrets-<cluster\_name>. | `string` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | Container image overrides for the controller / webhook / cert-controller. Left unset, the chart's own defaults apply. `registry` is prepended to `repository` to form the full image path (e.g. a private registry mirror). | <pre>object({<br/>    registry   = optional(string) # image registry host to prepend (e.g. a private registry); unset keeps the chart default<br/>    repository = optional(string) # image repository path (without registry host); unset keeps the chart default<br/>    tag        = optional(string) # image tag; unset keeps the chart default (chart appVersion)<br/>  })</pre> | `{}` | no |
| <a name="input_install_crds"></a> [install\_crds](#input\_install\_crds) | Whether the chart installs the external-secrets CRDs. | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install the external-secrets controller into. | `string` | `"kube-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | OIDC provider ARN for the IRSA trust policy. If null and resolve\_oidc\_from\_cluster is true, resolved from the cluster. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region of the cluster; used to build the OIDC issuer host for the IRSA trust policy. | `string` | `""` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name. | `string` | `"external-secrets"` | no |
| <a name="input_resolve_oidc_from_cluster"></a> [resolve\_oidc\_from\_cluster](#input\_resolve\_oidc\_from\_cluster) | Look up the OIDC provider from the EKS cluster when oidc\_provider\_arn is not supplied (IRSA only). | `bool` | `true` | no |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Service account name the controller runs as. Must match what the association/IRSA binds to. | `string` | `"external-secrets"` | no |
| <a name="input_store_role_name_prefix"></a> [store\_role\_name\_prefix](#input\_store\_role\_name\_prefix) | Naming prefix for per-store IAM roles. The controller is granted sts:AssumeRole on roles matching this prefix (role chaining), so it must match the store module's role naming. | `string` | `"external-secrets-store-"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | n/a | `number` | `300` | no |
| <a name="input_values"></a> [values](#input\_values) | Default Helm values map for the release. | `any` | `{}` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | n/a | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_controller_role_arn"></a> [controller\_role\_arn](#output\_controller\_role\_arn) | ARN of the controller's base IAM role; per-store roles trust this principal. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the controller is installed into. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Helm release name. |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | Service account the controller runs as. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
