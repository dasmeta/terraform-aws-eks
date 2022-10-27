locals {
  fluent_name    = var.fluent_bit_name != "" ? var.fluent_bit_name : "${var.cluster_name}-fluent-bit"
  log_group_name = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch"
  region         = var.region
  config_settings = {
    log_group_name     = local.log_group_name,
    region             = local.region,
    log_retention_days = var.log_retention_days
  }
}
