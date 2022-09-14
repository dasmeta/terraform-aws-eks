output "iam_permission_set_arns" {
  value = local.permission_set_role
}

output "data_ssoadmin_instances" {
  value = tolist(data.aws_ssoadmin_instances.this.arns)[0]
}
