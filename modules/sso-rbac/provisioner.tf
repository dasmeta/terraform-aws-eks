#module "eks_auth" {
#  #depends_on = [module.sso_account_assignments]
#  source = "aidanmelen/eks-auth/aws"
#  eks    = var.eks_module
#
#  map_roles = [for role_binding in var.bindings : {
#    rolearn  = [for role_arn in local.arns_without_path : role_arn if length(regexall(".+AWSReservedSSO_ps-${role_binding.namespace}-${role_binding.group}.+", role_arn)) > 0][0]
#   # rolearn  = [for role_arn in local.arns_without_path : role_arn if length(regexall(".+AWSReservedSSO_ps-accounting-accountants.+", role_arn)) > 0][0]
#    #rolearn  = "arn:aws:iam::794841639100:role/AWSReservedSSO_ps-accounting-accountants_77f776c1e80a1574"
#    username = role_binding.group
#    groups   = [role_binding.group]
#    }
#  ]
#}

#locals {
#  rolearn = [for role_arn in local.arns_without_path : role_arn][0]
#}




#resource "kubernetes_config_map_v1" "aws_auth" {
#  #count      = local.create_aws_auth_configmap ? 1 : 0
#  #depends_on = [data.http.wait_for_cluster]
#
#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }
#
#  data = {
#    "mapRoles"    = yamlencode(local.merged_map_roles)
#    "mapUsers"    = yamlencode(var.map_users)
#    "mapAccounts" = yamlencode(var.map_accounts)
#  }
#}

#locals {
#
#    #    rolearn  = [for role_arn in local.arns_without_path : role_arn if length(regexall(".+AWSReservedSSO_ps-${role_binding.namespace}-${role_binding.group}.+", role_arn)) > 0][0]
#  merged_map_roles = distinct(concat(
#    try(yamldecode(yamldecode(var.eks_module.aws_auth_configmap_yaml).data.mapRoles), []),
#
#    var.map_roles,
#  ))
#
#  aws_auth_configmap_yaml = templatefile("${path.module}/templates/aws_auth_cm.tpl",
#    {
#      map_roles    = local.merged_map_roles
#      map_users    = var.map_users
#      map_accounts = var.map_accounts
#    }
#  )
#}

#resource "kubernetes_config_map_v1_data" "aws_auth" {
# # count      = local.patch_aws_auth_configmap ? 1 : 0
#  #depends_on = [data.http.wait_for_cluster]
#
#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }
#
#  data = {
#    "mapRoles"    = yamlencode(local.merged_map_roles)
#    "mapUsers"    = yamlencode(var.map_users)
#    "mapAccounts" = yamlencode(var.map_accounts)
#  }
#
#  force = true
#}
#
#locals {
#  map
#}
