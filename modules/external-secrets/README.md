<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# How to use
This needs to be included in eks cluster along side with other services.

At this stage it does not require any credentials.

```
module external-secrets-staging {
  source = "dasmeta/terraform/modules/external-secrets"
}
```

After this one has to deploy specific stores which do contain credentials to pull secrets from AWS Secret Manager.

See related modules:
- external-secret-store
- aws-secret

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_release"></a> [release](#module\_release) | terraform-module/release/helm | 2.8.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace of kubernetes resources | `string` | `"kube-system"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
