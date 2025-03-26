module "fluent-bit" {
  source = "./modules/fluent-bit"

  count = var.create && var.fluent_bit_configs.enabled ? 1 : 0

  account_id = local.account_id
  region     = local.region

  cluster_name                = module.eks-cluster[0].cluster_name
  eks_oidc_root_ca_thumbprint = module.eks-cluster[0].eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn

  fluent_bit_name       = try(var.fluent_bit_configs.fluent_bit_name, "") != "" ? var.fluent_bit_configs.fluent_bit_name : "${module.eks-cluster[0].cluster_name}-fluent-bit"
  log_group_name        = try(var.fluent_bit_configs.log_group_name, "") != "" ? var.fluent_bit_configs.log_group_name : "fluent-bit-cloudwatch-${module.eks-cluster[0].cluster_name}"
  system_log_group_name = try(var.fluent_bit_configs.system_log_group_name, "")
  log_retention_days    = try(var.fluent_bit_configs.log_retention_days, 90)
  image_pull_secrets    = try(var.fluent_bit_configs.image_pull_secrets, [])

  values_yaml = try(var.fluent_bit_configs.values_yaml, "")

  drop_namespaces = try(var.fluent_bit_configs.drop_namespaces, [
    "kube-system",
    "opentelemetry-operator-system",
    "adot",
    "cert-manager",
    "opentelemetry.*",
    "meta.*",
  ])

  log_filters = try(var.fluent_bit_configs.log_filters, [
    "kube-probe",
    "health",
    "prometheus",
    "liveness"
  ])

  kube_namespaces = try(var.fluent_bit_configs.kube_namespaces, [
    "kube.*",
    "meta.*",
    "adot.*",
    "devops.*",
    "cert-manager.*",
    "git.*",
    "opentelemetry.*",
    "stakater.*",
    "renovate.*"
  ])

  additional_log_filters = try(var.fluent_bit_configs.additional_log_filters, [
    "ELB-HealthChecker",
    "Amazon-Route53-Health-Check-Service",
  ])

  fluent_bit_config = try(var.fluent_bit_configs.configs, {
    inputs                     = ""
    outputs                    = ""
    filters                    = ""
    cloudwatch_outputs_enabled = true
  })

  depends_on = [module.eks-core-components]
}
