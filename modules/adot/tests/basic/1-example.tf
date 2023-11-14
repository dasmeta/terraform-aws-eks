module "adot" {
  source = "../.."

  cluster_name                = "test-6"
  eks_oidc_root_ca_thumbprint = "3456789087654356789076546789"
  oidc_provider_arn           = "arn:aws:iam::888888676567:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/43567865435678654678"
  region                      = "eu-central-1"
}
