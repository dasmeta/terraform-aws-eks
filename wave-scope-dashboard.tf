module "weave-scope" {
  count            = var.weave_scope_enabled ? 1 : 0
  source           = "./modules/weave-scope"
  namespace        = var.weave_scope_config.namespace
  create_namespace = var.weave_scope_config.create_namespace
}
