output "data_psr" {
  value = data.aws_iam_roles.permission_set_arns
}

output "iam_permission_set_arns" {
  value = local.permission_set_role
}
