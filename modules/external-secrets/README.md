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
