data "aws_iam_roles" "sso" {
  depends_on  = [aws_ssoadmin_managed_policy_attachment.this]
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

module "eks_auth" {
  source = "aidanmelen/eks-auth/aws"
  #depends_on = [var.eks_module]
  eks = var.eks_module

  map_roles = [for role_binding in var.bindings : {
    rolearn  = [for role_arn in local.arns_without_path : role_arn if length(regexall(".+AWSReservedSSO_ps-${role_binding.namespace}-${role_binding.group}.+", role_arn)) > 0][0]
    username = role_binding.group
    groups   = [role_binding.group]
    }
  ]
}
