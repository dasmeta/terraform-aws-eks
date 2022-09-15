## Example
This is an example of usage `weave-scope` module


```
module "weave-scope" {
  source = "./modules/weave-scope"
  namespace = "weave"
  create_namespace = true
}

provider "helm" {
  kubernetes {
    host                   = cluster.host
    cluster_ca_certificate = cluster.certificate
    token                  = cluster.token
  }
}
```


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.weave-scope](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | n/a | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | `"default"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
