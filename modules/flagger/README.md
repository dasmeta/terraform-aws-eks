# terraform module allows to create/deploy flagger operator to have custom rollout strategies like canary/blue-green and also it allows to create custom flagger metric templates
## for more info check https://flagger.app and https://artifacthub.io/packages/helm/flagger/flagger


## example
```terraform
module "flagger" {
  source  = "dasmeta/eks/aws//modules/flagger"
  version = "2.18.0"

  configs = {
    meshProvider = "nginx"
    prometheus = {
      install = true # most possibly the prometheus is already installed, in that case set this to false and use `metricsServer` option to set the endpoint to prometheus
    }
  }
}
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.flagger_loadtester](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.flagger_metrics_and_alerts](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether use helm deploy with --atomic flag | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"1.40.0"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass and override default flagger chart configs. Check the helm chart available configs here: https://artifacthub.io/packages/helm/flagger/flagger?modal=values | `any` | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `true` | no |
| <a name="input_enable_loadtester"></a> [enable\_loadtester](#input\_enable\_loadtester) | Whether to install flagger loadtester helm | `bool` | `false` | no |
| <a name="input_load_tester_chart_version"></a> [load\_tester\_chart\_version](#input\_load\_tester\_chart\_version) | The flagger loadtester chart version | `string` | `"0.34.0"` | no |
| <a name="input_metric_template_chart_version"></a> [metric\_template\_chart\_version](#input\_metric\_template\_chart\_version) | The metric template chart version | `string` | `"0.1.0"` | no |
| <a name="input_metrics_and_alerts_configs"></a> [metrics\_and\_alerts\_configs](#input\_metrics\_and\_alerts\_configs) | Configurations to pass and override default flagger-metrics-and-alerts chart configs. If empty no chart will be deployed. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/flagger-metrics-and-alerts-0.1.0/charts/flagger-metrics-and-alerts | `any` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install main helm. | `string` | `"ingress-nginx"` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether use helm deploy with --wait flag | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_metadata"></a> [helm\_metadata](#output\_helm\_metadata) | Helm release metadata |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
