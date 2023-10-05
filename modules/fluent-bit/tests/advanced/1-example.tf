locals {
  oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/6F40EA94327Dh8956DDB9S0AE7907CFD"
}

module "fluent-bit" {
  source = "../../"

  account_id = 000000000000
  region     = "eu-central-1"

  cluster_name                = "Test"
  oidc_provider_arn           = local.oidc_provider_arn
  eks_oidc_root_ca_thumbprint = replace(local.oidc_provider_arn, "/.*id//", "")


  log_group_name        = "fluent-bit"
  system_log_group_name = "fluent-bit-kube"
  create_log_group      = true
  log_retention_days    = 7

  # values_yaml = templatefile("${path.module}/templates/values.yaml.tpl", {
  #   s3_bucket_name    = "testtesttest"
  #   region            = "eu-central-1"
  # })

  drop_namespaces = [
    "kube-system",
    "opentelemetry-operator-system",
    "adot",
    "cert-manager"
  ]

  additional_log_filters = [
    "ELB-HealthChecker",
    "Amazon-Route53-Health-Check-Service",
  ]

  log_filters = [
    "ELB-HealthChecker",
    "Amazon-Route53-Health-Check-Service",
    "kube-probe",
    "health",
    "prometheus",
    "liveness"
  ]

  # fluent_bit_config = {
  #   inputs  = templatefile("${path.module}/templates/inputs.yaml.tpl", {})
  #   outputs = templatefile("${path.module}/templates/outputs.yaml.tpl", {})
  #   filters = templatefile("${path.module}/templates/filters.yaml.tpl", {})
  # }

}

output "merged_inputs" {
  value = module.fluent-bit
}
