locals {
  map_users = flatten([
    for user in var.users : {
      userarn  = try(data.aws_iam_user.user_arn[user.username].arn, null)
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
    ingress_cluster_8088 = {
      description                   = "LinkerD to node groups"
      protocol                      = "tcp"
      from_port                     = 8088
      to_port                       = 8088
      type                          = "ingress"
      source_cluster_security_group = true
    },
    ingress_cluster_8089 = {
      description                   = "LinkerD to node groups"
      protocol                      = "tcp"
      from_port                     = 8089
      to_port                       = 8089
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
    ingress_cluster_self = {
      description = "Access Security Group Self"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    },
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  node_security_group_additional_rules = merge(local.node_security_group_rules, var.node_security_group_additional_rules)
}
