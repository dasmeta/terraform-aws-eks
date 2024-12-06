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
 *
 * ## Upgrading guide:
 *  - from <2.19.0 to >=2.19.0 version needs some manual actions as we upgraded underlying eks module from 18.x.x to 20.x.x,
 *    here you can find needed actions/changes docs and ready scripts which can be used:
 *    docs:
 *      https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-19.0.md
 *      https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-20.0.md
 *    params:
 *      The node group create_launch_template=false and launch_template_name="" pair params have been replaced with use_custom_launch_template=false
 *    scripts:
 *    ```sh
 *     # commands to move some states, run before applying the `terraform apply` for new version
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.kubernetes_config_map_v1_data.aws_auth[0]" "module.<eks-module-name>.module.eks-cluster[0].module.aws_auth_config_map.kubernetes_config_map_v1_data.aws_auth[0]"
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443_webhook\"]"
 *     terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443_webhook\"]"
 *     # command to run in case upgrading from <2.14.6 version, run before applying the `terraform apply` for new version
 *     terraform state rm "module.<eks-module-name>.module.autoscaler[0].aws_iam_policy.policy"
 *     # command to run when apply fails to create the existing resource "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
 *     terraform import "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_eks_access_entry.this[\"cluster_creator\"]" "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
 *     # command to apply when secret store fails to be linked, probably there will be need to remove the resource
 *     terraform import "module.secret_store.kubectl_manifest.main" external-secrets.io/v1beta1//SecretStore//app-test//default
 *    ```
 *
 *
 * ## How to run
 * ```hcl
 * data "aws_availability_zones" "available" {}
 *
 * locals {
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
 * }
 *
 *
 * #(Basic usage with example of using already created VPC)
 * data "aws_availability_zones" "available" {}
 *
 * locals {
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
 * }
 *
 * # Minimum
 *
 * module "cluster_min" {
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
 * }
 *
 * # Max @TODO: the max param passing setup needs to be checked/fixed
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
 * }
 * ```
 *
 * ## karpenter enabled
 * ### NOTES:
 * ###  - enabling karpenter automatically disables cluster auto-scaler
 * ###  - then enabling karpenter on existing old cluster there is possibility to see cycle-dependency error, to overcome this you need at first to apply main eks module change (`terraform apply --target "module.<eks-module-name>.module.eks-cluster"`) and then rest of cluster-autoloader destroy and karpenter install onse
 * ###  - when destroying cluster which have karpenter enabled there is possibility of failure on karpenter resource removal, you need to run destruction one more time to get it complete
 * ```terraform
 * module "eks" {
 *  source  = "dasmeta/eks/aws"
 *  version = "3.x.x"
 *  .....
 *  karpenter = {
 *   enabled = true
 *   configs = {
 *     replicas = 1
 *   }
 *   resource_configs_defaults = { # this is optional param, look into karpenter submodule to get available defaults
 *     limits = {
 *       cpu = 11 # the default is 10 and we can add limit restrictions on memory also
 *     }
 *   }
 *   resource_configs = {
 *     nodePools = {
 *       general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
 *     }
 *   }
 *  }
 *  .....
 * }
 * ```
 **/
module "vpc" {
  source  = "dasmeta/vpc/aws"
  version = "1.0.1"

  count = try(var.vpc.create.name) != null ? 1 : 0

  name               = var.vpc.create.name
  availability_zones = var.vpc.create.availability_zones
  cidr               = var.vpc.create.cidr
  private_subnets    = var.vpc.create.private_subnets
  public_subnets     = var.vpc.create.public_subnets
  public_subnet_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = 1
    },
    var.vpc.create.public_subnet_tags
  )
  private_subnet_tags = merge(
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = 1
    },
    var.vpc.create.private_subnet_tags
  )
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
  cluster_addons                       = var.cluster_addons
  tags = merge(
    var.tags,
    local.cluster_autoscaler_enabled ? {
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    } : {},
    var.karpenter.enabled ? { "karpenter.sh/discovery" = "${var.cluster_name}" } : {}
  )
}

module "cloudwatch-metrics" {
  source = "./modules/cloudwatch-metrics"

  count = var.metrics_exporter == "cloudwatch" ? 1 : 0

  account_id = local.account_id
  region     = local.region

  eks_oidc_root_ca_thumbprint = local.eks_oidc_root_ca_thumbprint
  oidc_provider_arn           = module.eks-cluster[0].oidc_provider_arn
  cluster_name                = module.eks-cluster[0].cluster_name
}

module "metrics-server" {
  source = "./modules/metrics-server"

  count = var.create ? 1 : 0

  name = var.metrics_server_name != "" ? var.metrics_server_name : "${module.eks-cluster[0].cluster_name}-metrics-server"
}

module "external-secrets" {
  source = "./modules/external-secrets"

  count = var.create && var.enable_external_secrets ? 1 : 0

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
  storage_classes  = var.efs_storage_classes
}

resource "helm_release" "cert-manager" {
  count = var.create_cert_manager ? 1 : var.metrics_exporter == "adot" ? 1 : 0

  namespace        = "cert-manager"
  create_namespace = true
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  atomic           = true
  version          = var.cert_manager_chart_version

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
  version          = var.kube_state_metrics_chart_version
  create_namespace = false
  atomic           = true

  set_list {
    name = "metricAllowlist"
    value = concat(var.prometheus_metrics, [
      "kube_deployment_spec_replicas",
      "kube_deployment_status_replicas_available"
    ])
  }
}

module "autoscaler" {
  source = "./modules/autoscaler"

  count                    = local.cluster_autoscaler_enabled ? 1 : 0
  cluster_name             = var.cluster_name
  cluster_oidc_arn         = module.eks-cluster[0].oidc_provider_arn
  eks_version              = var.cluster_version
  autoscaler_image_patch   = var.autoscaler_image_patch
  scale_down_unneeded_time = var.scale_down_unneeded_time
  requests                 = var.autoscaler_requests
  limits                   = var.autoscaler_limits

  depends_on = [module.eks-cluster]
}

# TODO: The main eks module supports addons, the only thing it needs is iam role to pass, maybe we can create iam role here and pass to main module to create addon and attach the role there
module "ebs-csi" {
  source = "./modules/ebs-csi"

  count            = var.enable_ebs_driver ? 1 : 0
  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  addon_version    = var.ebs_csi_version
}

module "api-gw-controller" {
  source = "./modules/api-gw"

  count = var.enable_api_gw_controller ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_oidc_arn = module.eks-cluster[0].oidc_provider_arn
  deploy_region    = var.api_gw_deploy_region

  api_gateway_resources = var.api_gateway_resources
  vpc_id                = var.api_gateway_resources[0].vpc_links != null ? module.vpc[0].id : null
  subnet_ids            = var.api_gateway_resources[0].vpc_links != null ? (var.vpc.create.private_subnets != {} ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids) : null
}

module "portainer" {
  count = var.enable_portainer ? 1 : 0

  source         = "./modules/portainer"
  host           = var.portainer_config.host
  enable_ingress = var.portainer_config.enable_ingress
}

module "external-dns" {
  count = var.create && var.external_dns.enabled ? 1 : 0

  source            = "./modules/external-dns"
  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks-cluster[0].oidc_provider_arn
  region            = local.region
  configs           = var.external_dns.configs

  depends_on = [
    module.eks-cluster
  ]
}

module "flagger" {
  count = var.create && var.flagger.enabled ? 1 : 0

  source                  = "./modules/flagger"
  namespace               = var.flagger.namespace
  configs                 = var.flagger.configs
  metric_template_configs = var.flagger.metric_template_configs
  enable_metric_template  = var.flagger.enable_metric_template
  enable_loadtester       = var.flagger.enable_loadtester

  depends_on = [
    module.eks-cluster
  ]
}

module "karpenter" {
  count = var.create && var.karpenter.enabled ? 1 : 0

  source                    = "./modules/karpenter"
  cluster_name              = var.cluster_name
  cluster_endpoint          = module.eks-cluster[0].host
  oidc_provider_arn         = module.eks-cluster[0].oidc_provider_arn
  subnet_ids                = module.eks-cluster[0].subnet_ids
  configs                   = var.karpenter.configs
  resource_configs          = var.karpenter.resource_configs
  resource_configs_defaults = var.karpenter.resource_configs_defaults

  depends_on = [
    module.eks-cluster
  ]
}
