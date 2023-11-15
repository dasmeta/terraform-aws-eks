module "adot" {
  source = "../.."

  cluster_name                = "stage-6"
  eks_oidc_root_ca_thumbprint = replace(try(data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn, ""), "/.*id//", "")
  oidc_provider_arn           = data.aws_iam_openid_connect_provider.test-cluster-oidc-provider.arn
  region                      = "eu-central-1"
}
