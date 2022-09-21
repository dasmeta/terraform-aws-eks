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
| <a name="input_annotations"></a> [annotations](#input\_annotations) | n/a | `map(string)` | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Weather create namespace or not | `bool` | `true` | no |
| <a name="input_ingress_class"></a> [ingress\_class](#input\_ingress\_class) | n/a | `string` | `"nginx"` | no |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace, in which Weave Scope will be deployed | `string` | `"meta-system"` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm chart release name | `string` | `"weave-scope"` | no |
| <a name="input_service_type"></a> [service\_type](#input\_service\_type) | n/a | `string` | `"ClusterIP"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
