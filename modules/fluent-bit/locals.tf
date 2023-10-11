locals {
  fluent_name    = var.fluent_bit_name != "" ? var.fluent_bit_name : "${var.cluster_name}-fluent-bit"
  log_group_name = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch"
  region         = var.region
  config_settings = {
    log_group_name         = local.log_group_name
    system_log_group_name  = var.system_log_group_name == "" ? "${local.log_group_name}-kube" : "${var.system_log_group_name}"
    region                 = local.region
    log_retention_days     = var.log_retention_days
    auto_create_group      = var.create_log_group ? "On" : "Off"
    drop_namespaces        = "(${join("|", var.drop_namespaces)})"
    log_filters            = "(${join("|", var.log_filters)})"
    additional_log_filters = "(${join("|", var.additional_log_filters)})"
    inputs                 = try(var.fluent_bit_config.inputs, "")
    outputs                = try(var.fluent_bit_config.outputs, "")
    filters                = try(var.fluent_bit_config.filters, "")
    kube_namespaces        = "^(${join("|", var.kube_namespaces)})"
  }

  values = var.values_yaml == "" ? templatefile("${path.module}/values.yaml.tpl", local.config_settings) : var.values_yaml
}
