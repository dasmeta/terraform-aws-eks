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
