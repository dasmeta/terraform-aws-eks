module "this" {
  source = "../.."

  cluster_name      = "test-cluster-with-karpenter"
  oidc_provider_arn = "<eks-oidc-provider-arn>"
}
