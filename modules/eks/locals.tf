locals {
  map_users = flatten([
    for user in var.users : {
      userarn  = data.aws_iam_user.user_arn[user.username].arn
      username = user.username
      groups   = lookup(user, "group", ["system:masters"])
    }
  ])
  node_security_group_rules = {
    ingress_cluster_8443 = {
      description                   = "Metric server to node groups"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    },
    ingress_cluster_9443 = {
      description                   = "ALB to node groups"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      type                          = "ingress"
      source_cluster_security_group = true
    },
  }

  node_security_group_additional_rules = merge(local.node_security_group_rules, var.node_security_group_additional_rules)
}
