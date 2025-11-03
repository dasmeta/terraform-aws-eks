locals {
  storage_classes = { for key, value in merge(var.configs, var.extra_configs) : key => merge(
    var.defaults,
    value,
    {
      parameters = merge(var.defaults.parameters, try(value.parameters, {}))
    }
  ) }
}
