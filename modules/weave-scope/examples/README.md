# examples

```
module "weave-scope" {
  source           = "./modules/weave-scope"
  namespace        = "weave-scope"
  create_namespace = true
  release_name     = "weave"
  ingress_class    = "nginx"
  ingress_host     = "www.weave-scope.com"
  ingress_name     = "weave-ingress"
  annotations      = {"key1" = "value1", "key2" = "value2"}
  service_type     = NodePort
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_weave-scope-minimal"></a> [weave-scope-minimal](#module\_weave-scope-minimal) | ./modules/weave-scope | n/a |
| <a name="module_weave-scope-with-ingress"></a> [weave-scope-with-ingress](#module\_weave-scope-with-ingress) | ./modules/weave-scope | n/a |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
