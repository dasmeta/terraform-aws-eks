locals {
  oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/6F40EA94327Dh8956DDB9S0AE7907CFD"
  region            = "eu-central-1"
}

module "fluent-bit" {
  source = "../../"

  cluster_name                = "Test"
  oidc_provider_arn           = local.oidc_provider_arn
  eks_oidc_root_ca_thumbprint = replace(local.oidc_provider_arn, "/.*id//", "")
  region                      = local.region
  account_id                  = 000000000000

  # If your fluent bit configuration is more complex than the module supports you can ingst a own yaml configuration file for the values.yaml of the helm chart.
  values_yaml = templatefile("${path.module}/templates/values.yaml.tpl", {
    log_group_name_application = "applogs"
    log_group_name_system      = "systemlogs"
    log_retention_days         = 7
    region                     = local.region
  })
}
