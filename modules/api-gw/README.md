# API Gateway controller

To enable API-Gateway controller in EKS cluster you need to set
```terraform
module "eks" {

...
enable_api_gw_controller = true
...

}
```

## How to deploy API from EKS using controller
API, and its dependent parts (integrations, routes, ...) are deployed with CRDs
which you can find [here](https://aws-controllers-k8s.github.io/community/docs/tutorials/apigatewayv2-reference-example/)


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.4.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_apigatewayv2_api.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_iam_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [helm_release.api-gw-release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_service_account.servciceaccount](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_APIs"></a> [APIs](#input\_APIs) | n/a | <pre>list(object({<br>    name                       = string<br>    protocol_type              = string<br>    route_selection_expression = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "api",<br>    "protocol_type": "WEBSOCKET",<br>    "route_selection_expression": "$request.body.action"<br>  },<br>  {<br>    "name": "api1",<br>    "protocol_type": "WEBSOCKET1",<br>    "route_selection_expression": "$request.body.action1"<br>  }<br>]</pre> | no |
| <a name="input_api_integrations"></a> [api\_integrations](#input\_api\_integrations) | n/a | `list(string)` | `[]` | no |
| <a name="input_api_stages"></a> [api\_stages](#input\_api\_stages) | n/a | `list(string)` | `[]` | no |
| <a name="input_api_vpc_links"></a> [api\_vpc\_links](#input\_api\_vpc\_links) | n/a | `list(string)` | `[]` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Chart version of api-gw | `string` | `"0.0.17"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name to pass to role | `string` | n/a | yes |
| <a name="input_cluster_oidc_arn"></a> [cluster\_oidc\_arn](#input\_cluster\_oidc\_arn) | Cluster OIDC arn to pass to policy | `string` | n/a | yes |
| <a name="input_deploy_region"></a> [deploy\_region](#input\_deploy\_region) | Region in which API gatewat will be configured | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
