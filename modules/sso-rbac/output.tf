output "iam_permission_set_arns" {
  value = local.permission_set_role
}

output "data_ssoadmin_instances" {
  value = tolist(data.aws_ssoadmin_instances.this.arns)[0]
}

output "arns_without_path" {
  value = local.arns_without_path
}

output "arns" {
  value = data.aws_iam_roles.sso.arns
  #value = local.rolearn
}

#output "iam_roles_with_data" {
#  value = data.
#}
