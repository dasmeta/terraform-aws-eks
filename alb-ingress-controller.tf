module "alb-ingress-controller" {
  source = "./modules/aws-load-balancer-controller"

  count = var.create && (var.alb_load_balancer_controller.enabled || var.nginx_ingress_controller_config.enabled) ? 1 : 0

  account_id = local.account_id
  region     = local.region

  cluster_name                = module.eks-cluster[0].cluster_name
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  enable_waf                  = var.alb_load_balancer_controller.enable_waf_for_alb
  configs                     = var.alb_load_balancer_controller.configs

  ## the load balancer access logs sync to s3=>lambda=>cloudwatch was disabled/commented-out so this params also need/can be commented,
  ## after then the fix be applied for enabling this functionality we can uncomment them
  # create_alb_log_bucket       = true
  # alb_log_bucket_name = var.alb_load_balancer_controller.alb_log_bucket_name != "" ? var.alb_load_balancer_controller.alb_log_bucket_name : "${module.eks-cluster[0].cluster_name}-ingress-controller-log-bucket"
  # alb_log_bucket_path = var.alb_load_balancer_controller.alb_log_bucket_path != "" ? var.alb_load_balancer_controller.alb_log_bucket_path : module.eks-cluster[0].cluster_name

  depends_on = [module.eks-cluster]
}
