/**
 * # Why
 *
 * To spin up complete eks with all necessary components.
 * Those include:
 * - vpc (NOTE: the vpc submodule moved into separate repo https://github.com/dasmeta/terraform-aws-vpc)
 * - eks cluster
 * - alb ingress controller
 * - fluentbit
 * - external secrets
 * - metrics to cloudwatch
 *
 * ## How to run
 * ```hcl
*data "aws_availability_zones" "available" {}
*
*locals {
*    cluster_endpoint_public_access = true
*    cluster_enabled_log_types = ["audit"]
*  vpc = {
*    create = {
*      name = "dev"
*      availability_zones = data.aws_availability_zones.available.names
*      private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
*      public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
*      cidr               = "172.16.0.0/16"
*      public_subnet_tags = {
*    "kubernetes.io/cluster/dev" = "shared"
*    "kubernetes.io/role/elb"    = "1"
*  }
*  private_subnet_tags = {
*    "kubernetes.io/cluster/dev"       = "shared"
*    "kubernetes.io/role/internal-elb" = "1"
*  }
*    }
*  }
*   cluster_name = "your-cluster-name-goes-here"
*  alb_log_bucket_name = "your-log-bucket-name-goes-here"
*
*  fluent_bit_name = "fluent-bit"
*  log_group_name  = "fluent-bit-cloudwatch-env"
*}
*
*
*#(Basic usage with example of using already created VPC)
*data "aws_availability_zones" "available" {}
*
*locals {
*    cluster_endpoint_public_access = true
*    cluster_enabled_log_types = ["audit"]
*
*  vpc = {
*    link = {
*      id = "vpc-1234"
*      private_subnet_ids = ["subnet-1", "subnet-2"]
*    }
*  }
*   cluster_name = "your-cluster-name-goes-here"
*  alb_log_bucket_name = "your-log-bucket-name-goes-here"
*
*  fluent_bit_name = "fluent-bit"
*  log_group_name  = "fluent-bit-cloudwatch-env"
*}
*
*# Minimum
*
*module "cluster_min" {
*  source  = "dasmeta/eks/aws"
*  version = "0.1.1"
*
*  cluster_name        = local.cluster_name
*  users               = local.users
*
*  vpc = {
*    link = {
*      id = "vpc-1234"
*      private_subnet_ids = ["subnet-1", "subnet-2"]
*    }
*  }
*
*}
*
*# Max @TODO: the max param passing setup needs to be checked/fixed
*
* module "cluster_max" {
*  source  = "dasmeta/eks/aws"
*  version = "0.1.1"
*
*  ### VPC
*  vpc = {
*    create = {
*      name = "dev"
*     availability_zones = data.aws_availability_zones.available.names
*     private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
*     public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
*     cidr               = "172.16.0.0/16"
*     public_subnet_tags = {
*   "kubernetes.io/cluster/dev" = "shared"
*   "kubernetes.io/role/elb"    = "1"
*  }
*  private_subnet_tags = {
*    "kubernetes.io/cluster/dev"       = "shared"
*    "kubernetes.io/role/internal-elb" = "1"
*  }
*    }
*  }
*
*  cluster_enabled_log_types = local.cluster_enabled_log_types
*  cluster_endpoint_public_access = local.cluster_endpoint_public_access
*
*  ### EKS
*  cluster_name          = local.cluster_name
*  manage_aws_auth       = true
*
*  # IAM users username and group. By default value is ["system:masters"]
*  user = [
*          {
*            username = "devops1"
*            group    = ["system:masters"]
*          },
*          {
*            username = "devops2"
*            group    = ["system:kube-scheduler"]
*          },
*          {
*            username = "devops3"
*          }
*  ]
*
*  # You can create node use node_group when you create node in specific subnet zone.(Note. This Case Ec2 Instance havn't specific name).
*  # Other case you can use worker_group variable.
*
*  node_groups = {
*    example =  {
*      name  = "nodegroup"
*      name-prefix     = "nodegroup"
*      additional_tags = {
*          "Name"      = "node"
*          "ExtraTag"  = "ExtraTag"
*      }
*
*      instance_type   = "t3.xlarge"
*      max_capacity    = 1
*      disk_size       = 50
*      create_launch_template = false
*      subnet = ["subnet_id"]
*    }
* }
*
* node_groups_default = {
*     disk_size      = 50
*     instance_types = ["t3.medium"]
*   }
*
* worker_groups = {
*   default = {
*     name              = "nodes"
*     instance_type     = "t3.xlarge"
*     asg_max_size      = 3
*     root_volume_size  = 50
*   }
* }
*
*  workers_group_defaults = {
*    launch_template_use_name_prefix = true
*    launch_template_name            = "default"
*    root_volume_type                = "gp2"
*    root_volume_size                = 50
*  }
*
*  ### ALB-INGRESS-CONTROLLER
*  alb_log_bucket_name = local.alb_log_bucket_name
*
*  ### FLUENT-BIT
*  fluent_bit_name = local.fluent_bit_name
*  log_group_name  = local.log_group_name
*
*  # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
*  ### METRICS-SERVER
*  # enable_metrics_server = false
*  metrics_server_name     = "metrics-server"
}
 * ```
 **/
module "vpc" {
  source  = "dasmeta/vpc/aws"
  version = "1.0.1"

  count = try(var.vpc.create.name) != null ? 1 : 0

  name                = var.vpc.create.name
  availability_zones  = var.vpc.create.availability_zones
  cidr                = var.vpc.create.cidr
  private_subnets     = var.vpc.create.private_subnets
  public_subnets      = var.vpc.create.public_subnets
  public_subnet_tags  = var.vpc.create.public_subnet_tags
  private_subnet_tags = var.vpc.create.private_subnet_tags
}

module "eks-cluster" {
  source = "./modules/eks"
  count  = var.create ? 1 : 0

  region = local.region

  cluster_name = var.cluster_name
  vpc_id       = var.vpc.create.name != null ? module.vpc[0].id : var.vpc.link.id
  subnets      = var.vpc.create.name != null ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids

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

  count = var.metrics_exporter == "cloudwatch" ? 1 : 0

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

  ## the load balancer access logs sync to s3=>lambda=>cloudwatch was disabled/commented-out so this params also need/can be commented,
  ## after then the fix be applied for enabling this functionality we can uncomment them
  # create_alb_log_bucket       = true
  # alb_log_bucket_name = var.alb_log_bucket_name != "" ? var.alb_log_bucket_name : "${module.eks-cluster[0].cluster_id}-ingress-controller-log-bucket"
  # alb_log_bucket_path = var.alb_log_bucket_path != "" ? var.alb_log_bucket_path : module.eks-cluster[0].cluster_id
}

module "fluent-bit" {
  source = "./modules/fluent-bit"

  count = var.create ? 1 : 0

  account_id = local.account_id
  region     = local.region

  fluent_bit_name             = var.fluent_bit_name != "" ? var.fluent_bit_name : "${module.eks-cluster[0].cluster_id}-fluent-bit"
  log_group_name              = var.log_group_name != "" ? var.log_group_name : "fluent-bit-cloudwatch-${module.eks-cluster[0].cluster_id}"
  log_retention_days          = var.log_retention_days
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

module "efs-csi-driver" {
  source = "./modules/efs-csi"

  count            = var.enable_efs_driver ? 1 : 0
  cluster_name     = var.cluster_name
  efs_id           = var.efs_id
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
}

module "adot" {
  source = "./modules/adot"

  count = var.metrics_exporter == "adot" ? 1 : 0

  cluster_name                = var.cluster_name
  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  adot_config                 = var.adot_config
  region                      = local.region
  depends_on = [
    module.eks-cluster,
    helm_release.cert-manager
  ]
  providers = { "aws" : "aws", "kubernetes" : "kubernetes", "kubectl" = "kubectl" }
}

resource "helm_release" "cert-manager" {
  count = var.create_cert_manager ? 1 : var.metrics_exporter == "adot" ? 1 : 0

  namespace        = "cert-manager"
  create_namespace = true
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  atomic           = true
  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    module.eks-cluster
  ]
}

resource "helm_release" "kube-state-metrics" {
  count = var.enable_kube_state_metrics ? 1 : 0

  name             = "kube-state-metrics"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-state-metrics"
  namespace        = "kube-system"
  version          = "4.22.3"
  create_namespace = false
  atomic           = true
}

module "autoscaler" {
  source = "./modules/autoscaler"

  count                    = var.autoscaling ? 1 : 0
  cluster_name             = var.cluster_name
  cluster_oidc_arn         = module.eks-cluster[0].oidc_provider_arn
  eks_version              = var.cluster_version
  autoscaler_image_patch   = var.autoscaler_image_patch
  scale_down_unneeded_time = var.scale_down_unneeded_time
  requests                 = var.autoscaler_requests
  limits                   = var.autoscaler_limits
}

module "ebs-csi" {
  source = "./modules/ebs-csi"

  count            = var.enable_ebs_driver ? 1 : 0
  cluster_name     = var.cluster_name
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  addon_version    = var.ebs_csi_version
}

module "api-gw-controller" {
  source = "./modules/api-gw"

  count = var.enable_api_gw_controller ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  deploy_region    = var.api_gw_deploy_region
}
