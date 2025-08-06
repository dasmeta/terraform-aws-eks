# Node Problem detector
Component will detect and report issues to k8s api server and prometheus.

See helm and git repos for details.
https://github.com/kubernetes/node-problem-detector
https://artifacthub.io/packages/helm/deliveryhero/node-problem-detector
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_node-problem-detector"></a> [node-problem-detector](#module\_node-problem-detector) | terraform-module/release/helm | 2.8.2 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version to use | `string` | `"2.3.14"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | Configurations to pass to underlying helm chart | `any` | <pre>{<br/>  "annotations": {<br/>    "prometheus.io/port": "20257",<br/>    "prometheus.io/scrape": "true"<br/>  },<br/>  "settings": {<br/>    "prometheus_port": 20257<br/>  }<br/>}</pre> | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
