module "this" {
  source = "../.."

  cluster_name      = "test-cluster-with-karpenter"
  cluster_endpoint  = "<endpoint-to-eks-cluster>"
  oidc_provider_arn = "<eks-oidc-provider-arn>"
}
