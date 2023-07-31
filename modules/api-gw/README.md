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
| [aws_apigatewayv2_integration.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_apigatewayv2_vpc_link.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_vpc_link) | resource |
| [aws_iam_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_security_group.api-gw-sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [helm_release.api-gw-release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_service_account.servciceaccount](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_APIs"></a> [APIs](#input\_APIs) | API Gateway's API and its dependent parts configurations | <pre>list(object({<br>    name                         = string<br>    protocol_type                = string<br>    route_selection_expression   = optional(string)<br>    api_key_selection_expression = optional(string)<br>    credentials_arn              = optional(string)<br>    description                  = optional(string)<br>    disable_execute_api_endpoint = optional(bool)<br>    disable_schema_validation    = optional(bool)<br>    version                      = optional(string)<br>    tags                         = optional(map(string))<br><br><br>    integrations = list(object({<br>      integration_name              = string<br>      integration_type              = string<br>      connection_type               = optional(string)<br>      integration_uri               = string<br>      payload_format_version        = optional(string)<br>      template_selection_expression = optional(string)<br>      connection_type               = optional(string)<br>      connection_id                 = optional(string)<br>      description                   = optional(string)<br>      request_parameters            = optional(map(string))<br>      timeout_milliseconds          = optional(number)<br>      content_handling_strategy     = optional(string)<br>      credentials_arn               = optional(string)<br>      integration_method            = optional(string)<br>    }))<br><br>    routes = list(object({<br>      integration_name                    = string<br>      route_key                           = string<br>      api_key_required                    = optional(bool)<br>      authorization_type                  = optional(string)<br>      authorizer_id                       = optional(string)<br>      model_selection_expression          = optional(string)<br>      operation_name                      = optional(string)<br>      request_models                      = optional(map(string))<br>      request_parameters                  = optional(map(string))<br>      route_response_selection_expression = optional(string)<br>    }))<br><br><br>    stages = list(object({<br>      name                  = string<br>      description           = optional(string)<br>      client_certificate_id = optional(string)<br>      stage_variables       = optional(map(string))<br>      tags                  = optional(map(string))<br>    }))<br>  }))</pre> | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Chart version of api-gw | `string` | `"0.0.17"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name to pass to role | `string` | n/a | yes |
| <a name="input_cluster_oidc_arn"></a> [cluster\_oidc\_arn](#input\_cluster\_oidc\_arn) | Cluster OIDC arn to pass to policy | `string` | n/a | yes |
| <a name="input_deploy_region"></a> [deploy\_region](#input\_deploy\_region) | Region in which API gatewat will be configured | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | EKS private Subnet IDs to pass inside module | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id, needed for vpc link | `string` | n/a | yes |
| <a name="input_vpc_link_name"></a> [vpc\_link\_name](#input\_vpc\_link\_name) | VPC link name | `string` | `""` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
