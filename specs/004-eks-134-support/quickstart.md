# Quickstart: Validate EKS 1.34 Module Support

Run from the repository root.

```bash
terraform fmt -recursive
```

```bash
terraform init -backend=false
```

```bash
terraform validate
```

Regenerate root and affected module docs after Terraform edits. Keep the existing pre-commit-terraform markers:

```bash
terraform-docs markdown table --output-file README.md --output-mode replace --output-template '<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
{{ .Content }}
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->' .
```

Run the same command for each affected submodule path: `modules/eks`, `modules/adot`, `modules/ebs-csi`, `modules/s3-csi`, `modules/autoscaler`, `modules/keda`, `modules/external-secrets`, `modules/metrics-server`, `modules/nginx-ingress-controller`, and `modules/linkerd`.

Check for stale defaults and legacy External Secrets example APIs:

```bash
rg -n 'default\\s+=\\s+"1\\.33"|external-secrets.io/v1beta1|2\\.16\\.1|4\\.12\\.0|7\\.4\\.1|0\\.15\\.0|1\\.16\\.11|30\\.12\\.11|1\\.8\\.0'
```

Targeted Helm checks:

```bash
helm show chart oci://registry-1.docker.io/bitnamicharts/metrics-server --version 7.4.12
helm search repo prometheus-community/kube-state-metrics --versions --max-col-width=0
helm show values linkerd-edge/linkerd-control-plane --version 2025.10.7
helm show values linkerd-edge/linkerd-viz --version 2025.10.7
```

For production Linkerd users, pre-upgrade validation is required outside this module change:

```bash
linkerd check
linkerd check --proxy
```

For client delivery, first apply required tooling changes with the live cluster version pinned, then upgrade EKS:

```hcl
cluster_version = "1.33"
```

Remove or change that pin only after required tooling upgrades have passed validation.
