module "alb-ingress-controller" {
  source = "./modules/aws-load-balancer-controller"

  count = var.create && (var.alb_load_balancer_controller.enabled || var.nginx_ingress_controller_config.enabled) ? 1 : 0

  region = local.region

  cluster_name = module.eks-cluster[0].cluster_name

  oidc_provider_arn                   = module.eks-cluster[0].oidc_provider_arn
  enable_waf                          = var.alb_load_balancer_controller.enable_waf_for_alb
  chart                               = var.alb_load_balancer_controller.chart
  image                               = var.alb_load_balancer_controller.image
  iam                                 = var.alb_load_balancer_controller.iam
  use_service_account_role_annotation = var.alb_load_balancer_controller.use_service_account_role_annotation
  create_pod_identity_association     = var.alb_load_balancer_controller.create_pod_identity_association
  configs                             = var.alb_load_balancer_controller.configs
  vpc_id                              = local.vpc_id

  depends_on = [module.eks-core-components]
}
