module "weave-scope" {
  count            = var.weave_scope_enabled ? 1 : 0
  source           = "./modules/weave-scope"
  namespace        = var.weave_scope_config.namespace
  create_namespace = var.weave_scope_config.create_namespace
  release_name     = var.weave_scope_config.weave_helm_release_name
  ingress_class    = var.weave_scope_config.ingress_class
  ingress_host     = var.weave_scope_config.ingress_host
  annotations      = var.weave_scope_config.annotations
  service_type     = var.weave_scope_config.service_type
}
