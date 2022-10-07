module "sso_account_assignments" {
  source   = "./terraform-aws-sso/modules/account-assignments"
  for_each = { for kr in var.bindings : "${kr.namespace}-${kr.group}" => kr }
  account_assignments = [
    {
      permission_set_name = "ps-${each.value.namespace}-${each.value.group}"
      account             = var.account_id
      permission_set_arn  = module.permission_sets[each.key].permission_sets["ps-${each.key}"].arn
      principal_type      = "GROUP",
      principal_name      = "${each.value.group}"
    }
  ]
}

data "aws_ssoadmin_instances" "this" {}

data "aws_identitystore_group" "this" {
  for_each          = { for as in var.bindings : "${as.namespace}-${as.group}" => as }
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  filter {
    attribute_path  = local.attribute_path
    attribute_value = each.value.group
  }
}



locals {
  attribute_path      = "DisplayName"
  principal_type      = "GROUP"
  target_type         = "AWS_ACCOUNT"
  permission_set_role = local.arns_without_path
}
