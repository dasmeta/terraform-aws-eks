<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

# terraform module allows to create/deploy linkerd into eks cluster
TODOs:
 - check and set more default values for default setup, for example the plain helm charts components do not have resources requests/limits and in low resource situations this can result some issues
 - consider moving this submodule to general/shared module as this module is not eks specific and it can be used with any k8s setup

## basic usage example
```terraform
module "this" {
  source  = "dasmeta/eks/aws//modules/linkerd"
  version = "2.22.0"
}
```

**/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_default_configs_together"></a> [custom\_default\_configs\_together](#module\_custom\_default\_configs\_together) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_custom_default_configs_viz_together"></a> [custom\_default\_configs\_viz\_together](#module\_custom\_default\_configs\_viz\_together) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_identity_certificates_and_keys"></a> [identity\_certificates\_and\_keys](#module\_identity\_certificates\_and\_keys) | ./modules/identity-certificates-and-keys | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.this_crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.this_viz](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether use helm deploy with --atomic flag | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The linkerd chart version | `string` | `"1.16.11"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass and override default ones for linkerd. Check the helm chart available configs  here: https://artifacthub.io/packages/helm/linkerd2/linkerd2 | `any` | `{}` | no |
| <a name="input_configs_viz"></a> [configs\_viz](#input\_configs\_viz) | Configurations to pass and override default ones for linkerd\_viz. Check the helm chart available configs for specified var.viz\_chart\_version here: https://artifacthub.io/packages/helm/linkerd2/linkerd-viz | `any` | `{}` | no |
| <a name="input_crds_chart_version"></a> [crds\_chart\_version](#input\_crds\_chart\_version) | The app crds chart version | `string` | `"1.8.0"` | no |
| <a name="input_crds_create"></a> [crds\_create](#input\_crds\_create) | Whether to create linkerd crds | `bool` | `true` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install main helm. | `string` | `"linkerd"` | no |
| <a name="input_resourcesDefaults"></a> [resourcesDefaults](#input\_resourcesDefaults) | The default/shared container memory/cpu request/limits to use in all containers. For now we have only requests set to have minimal resources for services. | `any` | <pre>{<br/>  "cpu": {<br/>    "request": "100m"<br/>  },<br/>  "memory": {<br/>    "request": "128Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_viz_chart_version"></a> [viz\_chart\_version](#input\_viz\_chart\_version) | The dashboard/monitoring chart version for linkerd | `string` | `"30.12.11"` | no |
| <a name="input_viz_create"></a> [viz\_create](#input\_viz\_create) | Whether to create linkerd viz dashboards | `bool` | `true` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether use helm deploy with --wait flag | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_metadata"></a> [helm\_metadata](#output\_helm\_metadata) | Helm release metadata |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
