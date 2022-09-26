data "aws_caller_identity" "current" {}

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

data "aws_identitystore_group" "this" {
  for_each          = { for as in var.bindings : "${as.namespace}-${as.group}" => as }
  identity_store_id = "d-c3672b5a4b"

  filter {
    attribute_path  = local.attribute_path
    attribute_value = each.value.group
  }
}

locals {
  # identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  identity_store_id = trimspace(file("${path.module}/resources/identity_store_id"))
  attribute_path    = "DisplayName"
  instance_arn      = trimspace(file("${path.module}/resources/instance_arn"))
  principal_type    = "GROUP"
  #  target_id           = data.aws_caller_identity.current.account_id
  target_type         = "AWS_ACCOUNT"
  permission_set_role = local.arns_without_path
}
