locals {
  eks_oidc_root_ca_thumbprint = replace(module.eks-cluster.oidc_provider_arn, "/.*id//", "")
}

data "aws_region" "current" {}

module "vpc" {
  source = "./modules/vpc"

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

  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnets      = module.vpc.vpc_private_subnets

  users                          = var.users
  node_groups                    = var.node_groups
  node_groups_default            = var.node_groups_default
  worker_groups                  = var.worker_groups
  workers_group_defaults         = var.workers_group_defaults
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_enabled_log_types      = var.cluster_enabled_log_types
  cluster_version                = var.cluster_version
  map_roles                      = var.map_roles
}

module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster.oidc_provider_arn
  cluster_name                = var.cluster_name

  # providers = {
  #   kubernetes = kubernetes
  # }
}

module "alb-ingress-controller" {
  source = "./modules/aws-load-balancer-controller"

  cluster_name                = var.cluster_name
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster.oidc_provider_arn
  create_alb_log_bucket       = true
  alb_log_bucket_name         = var.alb_log_bucket_name != "" ? var.alb_log_bucket_name : "${var.cluster_name}-ingress-controller-log-bucket"
  alb_log_bucket_prefix       = var.alb_log_bucket_prefix != "" ? var.alb_log_bucket_prefix : var.cluster_name

  # providers = {
  #   kubernetes = kubernetes
  # }
}

module "fluent-bit" {
  source = "./modules/fluent-bit"

  fluent_bit_name             = var.fluent_bit_name != "" ? var.fluent_bit_name : "${var.cluster_name}-fluent-bit"
  log_group_name              = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch-${var.cluster_name}"
  cluster_name                = var.cluster_name
  eks_oidc_root_ca_thumbprint = module.eks-cluster.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster.oidc_provider_arn

  region = data.aws_region.current.name
  # providers = {
  #   kubernetes = kubernetes
  # }
}

module "metrics-server" {
  # count = var.enable_metrics_server == true ? 1 : 0

  source = "./modules/metrics-server"
  name   = var.metrics_server_name != "" ? var.metrics_server_name : "${var.cluster_name}-metrics-server"

  # providers = {
  #   kubernetes = kubernetes
  # }
}

module "external-secrets-prod" {
  source = "./modules/external-secrets"

  namespace = var.external_secrets_namespace
  # providers = {
  #   kubernetes = kubernetes
  # }
}
