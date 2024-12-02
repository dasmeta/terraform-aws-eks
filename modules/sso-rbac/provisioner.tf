module "eks_auth" {
  source  = "aidanmelen/eks-auth/aws"
  eks     = var.eks_module
  version = "1.0.0"

  map_roles = [for role_binding in var.bindings : {
    rolearn  = [for role_arn in local.arns_without_path : role_arn if length(regexall(".+AWSReservedSSO_ps-${role_binding.namespace}-${role_binding.group}.+", role_arn)) > 0][0]
    username = role_binding.group
    groups   = [role_binding.group]
    }
  ]
}
