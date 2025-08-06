# terraform module to install node-local-dns(NodeLocal DNSCache) helm chart and enable dns cache on k8s clusters
NodeLocal DNSCache improves Cluster DNS performance by running a DNS caching agent on cluster nodes as a DaemonSet.

For details check: https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_default_configs"></a> [custom\_default\_configs](#module\_custom\_default\_configs) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_node-problem-detector"></a> [node-problem-detector](#module\_node-problem-detector) | terraform-module/release/helm | 2.8.2 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_service.dns_service](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The helm chart version to use | `string` | `"2.1.10"` | no |
| <a name="input_configs"></a> [configs](#input\_configs) | The extra config values to pass to chart, for possible configs check: https://artifacthub.io/packages/helm/deliveryhero/node-local-dns/2.1.10?modal=values | `any` | `{}` | no |
| <a name="input_core_dns_service_name"></a> [core\_dns\_service\_name](#input\_core\_dns\_service\_name) | The name of core-dns/kube-dns service which will be used to auto-identify local-dns required config named dnsServer | `string` | `"kube-dns"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of helm release | `string` | `"node-local-dns"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace where the service will be installed | `string` | `"kube-system"` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether to wait for helm chart to be successful deployed | `bool` | `true` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
