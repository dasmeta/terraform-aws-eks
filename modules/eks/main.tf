data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster[0].cluster_id
}

data "aws_iam_user" "user_arn" {
  for_each  = { for user in var.users : user.username => user }
  user_name = each.value.username
}

module "eks-cluster" {
  count = var.create_cluster ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.1"

  # per Upgrade from v17.x to v18.x, see here for details https://github.com/terraform-aws-modules/terraform-aws-eks/blob/681e00aafea093be72ec06ada3825a23a181b1c5/docs/UPGRADE-18.0.md
  prefix_separator                   = ""
  iam_role_name                      = var.cluster_name
  cluster_security_group_name        = var.cluster_name
  cluster_security_group_description = "EKS cluster security group."

  # Required parameters
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnets

  node_security_group_additional_rules = local.node_security_group_additional_rules

  enable_irsa                     = var.enable_irsa
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_enabled_log_types       = var.cluster_enabled_log_types

  self_managed_node_groups         = var.worker_groups
  self_managed_node_group_defaults = var.workers_group_defaults
  eks_managed_node_group_defaults  = var.node_groups_default
  eks_managed_node_groups          = var.node_groups

  manage_aws_auth_configmap = true
  aws_auth_users            = local.map_users
  aws_auth_roles            = var.map_roles

  tags = {
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  }
}

resource "null_resource" "enable_cloudwatch_metrics_autoscaling" {
  count = length(var.node_groups)

  provisioner "local-exec" {
    command     = "aws autoscaling enable-metrics-collection --granularity \"1Minute\" --auto-scaling-group-name  ${compact(flatten([for group in module.eks-cluster : group.eks_managed_node_groups_autoscaling_group_names]))[count.index]}"
    interpreter = ["bash", "-c"]
  }
  depends_on = [
    module.eks-cluster
  ]
}
