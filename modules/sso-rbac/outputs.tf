output "role_arns_without_path" {
  value = local.arns_without_path
}

output "role_arns" {
  value = data.aws_iam_roles.sso.arns
}

output "config_yaml" {
  value = module.eks_auth.aws_auth_configmap_yaml
}
