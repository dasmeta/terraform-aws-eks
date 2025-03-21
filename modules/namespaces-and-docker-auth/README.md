<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

# terraform module allows to create/deploy application namespaces into eks cluster, with configuring docker registry image pull secrets

## example
```terraform
module "this" {
  source  = "dasmeta/eks/aws//modules/namespaces-and-docker-auth"

  cluster_name      = "test-cluster-with-linkerd"
  cluster_endpoint  = "<endpoint-to-eks-cluster>"
  oidc_provider_arn = "<eks-oidc-provider-arn>"
  region            = "eu-central-1"
  configs           = {} # the default should work, but there are some dependencies, like aws secret should be created already
}
```

**/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_default_configs_deep"></a> [custom\_default\_configs\_deep](#module\_custom\_default\_configs\_deep) | cloudposse/config/yaml//modules/deepmerge | 1.0.2 |
| <a name="module_dockerhub_auth_secret_iam_eks_role"></a> [dockerhub\_auth\_secret\_iam\_eks\_role](#module\_dockerhub\_auth\_secret\_iam\_eks\_role) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.53.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | Whether use helm deploy with --atomic flag | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | The app chart version | `string` | `"0.1.0"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | The eks cluster endpoint | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The eks cluster name | `string` | n/a | yes |
| <a name="input_configs"></a> [configs](#input\_configs) | The main configurations | <pre>object({<br/>    list   = optional(list(string), []) # list of application namespaces to create/init with cluster creation<br/>    labels = optional(any, {})          # map of key=>value strings to attach to namespaces<br/>    dockerAuth = optional(object({      # docker hub image registry configs, this based external secrets operator(operator should be enabled). which will allow to create 'kubernetes.io/dockerconfigjson' type secrets in app(and also all other) namespaces and configure app namespaces to use this<br/>      enabled                 = optional(bool, false)<br/>      refreshTime             = optional(string, "3m")                                         # frequency to check filtered namespaces and create ExternalSecrets (and k8s secret)<br/>      refreshInterval         = optional(string, "1h")                                         # frequency to pull/refresh data from aws secret<br/>      name                    = optional(string, "docker-registry-auth")                       # the name to use when creating k8s resources<br/>      secretManagerSecretName = optional(string, "account")                                    # aws secret manager secret name where dockerhub credentials placed, we use "account" default secret<br/>      namespaceSelector       = optional(any, { matchLabels : { "docker-auth" = "enabled" } }) # namespaces selector expression, the app namespaces created here will have this selectors by default, but for other namespaces you may need to set labels manually. this can be set to empty object {} to create secrets in all namespaces<br/>      registries = optional(list(object({                                                      # docker registry configs<br/>        url         = optional(string, "https://index.docker.io/v1/")                          # docker registry server url<br/>        usernameKey = optional(string, "DOCKER_HUB_USERNAME")                                  # the aws secret manager secret key where docker registry username placed<br/>        passwordKey = optional(string, "DOCKER_HUB_PASSWORD")                                  # the aws secret manager secret key where docker registry password placed, NOTE: for dockerhub under this key should be set personal access token instead of standard ui/profile password<br/>        authKey     = optional(string)                                                         # the aws secret manager secret key where docker registry auth placed<br/>      })), [{ url = "https://index.docker.io/v1/", usernameKey = "DOCKER_HUB_USERNAME", passwordKey = "DOCKER_HUB_PASSWORD", authKey = null }])<br/>    }), { enabled = false })<br/>  })</pre> | `{}` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Create namespace if requested | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The helm release name | `string` | `"app-namespaces"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to install main helm. | `string` | `"meta-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The aws region | `string` | n/a | yes |
| <a name="input_wait"></a> [wait](#input\_wait) | Whether use helm deploy with --wait flag | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_metadata"></a> [helm\_metadata](#output\_helm\_metadata) | Helm release metadata |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
