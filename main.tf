module "vpc" {
  source = "./modules/vpc"
  count  = var.create ? 1 : 0

  vpc_name            = var.vpc_name
  availability_zones  = var.availability_zones
  cidr                = var.cidr
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags
}

module "eks-cluster" {
  source = "./modules/eks"

  count = var.create ? 1 : 0

  region = local.region

  cluster_name = var.cluster_name
  vpc_id       = module.vpc[0].id
  subnets      = module.vpc[0].private_subnets

  users                                = var.users
  node_groups                          = var.node_groups
  node_groups_default                  = var.node_groups_default
  worker_groups                        = var.worker_groups
  workers_group_defaults               = var.workers_group_defaults
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_version                      = var.cluster_version
  map_roles                            = var.map_roles
  node_security_group_additional_rules = var.node_security_group_additional_rules
}

module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  count = var.create ? 1 : 0

  account_id = local.account_id
  region     = local.region

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  cluster_name                = module.eks-cluster[0].cluster_id
}

module "alb-ingress-controller" {
  source = "./modules/aws-load-balancer-controller"

  count = var.create ? 1 : 0

  account_id = local.account_id
  region     = local.region

  cluster_name                = module.eks-cluster[0].cluster_id
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  create_alb_log_bucket       = true
  alb_log_bucket_name         = var.alb_log_bucket_name != "" ? var.alb_log_bucket_name : "${module.eks-cluster[0].cluster_id}-ingress-controller-log-bucket"
  alb_log_bucket_path         = var.alb_log_bucket_path != "" ? var.alb_log_bucket_path : module.eks-cluster[0].cluster_id
}

module "fluent-bit" {
  source = "./modules/fluent-bit"

  count = var.create ? 1 : 0

  account_id = local.account_id
  region     = local.region

  fluent_bit_name             = var.fluent_bit_name != "" ? var.fluent_bit_name : "${module.eks-cluster[0].cluster_id}-fluent-bit"
  log_group_name              = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch-${module.eks-cluster[0].cluster_id}"
  cluster_name                = module.eks-cluster[0].cluster_id
  eks_oidc_root_ca_thumbprint = module.eks-cluster[0].eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
}

module "metrics-server" {
  source = "./modules/metrics-server"

  count = var.create ? 1 : 0

  name = var.metrics_server_name != "" ? var.metrics_server_name : "${module.eks-cluster[0].cluster_id}-metrics-server"
}

module "external-secrets" {
  source = "./modules/external-secrets"

  count = var.create ? 1 : 0

  namespace = var.external_secrets_namespace

  depends_on = [
    module.eks-cluster
  ]
}

module "sso-rbac" {
  source = "./modules/sso-rbac"

  count = var.enable_sso_rbac && var.create ? 1 : 0

  account_id = local.account_id

  roles      = var.roles
  bindings   = var.bindings
  eks_module = module.eks-cluster[0].eks_module

  depends_on = [
    module.eks-cluster
  ]
}
