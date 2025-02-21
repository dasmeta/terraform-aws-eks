module "nginx-ingress-controller" {
  source = "./modules/nginx-ingress-controller/"

  count = var.create && var.nginx_ingress_controller_config.enabled ? 1 : 0

  name             = var.nginx_ingress_controller_config.name
  create_namespace = var.nginx_ingress_controller_config.create_namespace
  namespace        = var.nginx_ingress_controller_config.namespace
  replicacount     = var.nginx_ingress_controller_config.replicacount
  metrics_enabled  = var.nginx_ingress_controller_config.metrics_enabled
  configs          = var.nginx_ingress_controller_config.configs

  depends_on = [module.alb-ingress-controller]
}
