/**
 *
 * # terraform module allows to create/deploy application namespaces into eks cluster, with configuring docker registry image pull secrets
 *
 * ## example
 * ```terraform
 * module "this" {
 *   source  = "dasmeta/eks/aws//modules/namespaces-and-docker-auth"
 *
 *   cluster_name      = "test-cluster-with-linkerd"
 *   cluster_endpoint  = "<endpoint-to-eks-cluster>"
 *   oidc_provider_arn = "<eks-oidc-provider-arn>"
 *   region            = "eu-central-1"
 *   configs           = {} # the default should work, but there are some dependencies, like aws secret should be created already
 * }
 * ```
 *
 *
**/

resource "helm_release" "this" {
  name             = var.name
  repository       = "https://dasmeta.github.io/helm"
  chart            = "namespaces-and-docker-auth"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(module.custom_default_configs_deep.merged)]
}

module "custom_default_configs_deep" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
    {
      dockerAuth = {
        serviceAccountRoleArn = try(module.dockerhub_auth_secret_iam_eks_role[0].iam_role_arn, null)
        region                = local.region
      }
    },
    var.configs
  ]
}
