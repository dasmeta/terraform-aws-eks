data "aws_ssoadmin_instances" "this" {}

module "permission_sets" {
  source = "github.com/cloudposse/terraform-aws-sso.git//modules/permission-sets?ref=master"

  for_each = { for kr in var.bindings : "${kr.namespace}-${kr.group}" => kr }
  permission_sets = [
    {
      name                                = "ps-${each.value.namespace}-${each.value.group}"
      tags                                = {},
      policy_attachments                  = ["arn:aws:iam::aws:policy/PowerUserAccess"]
      customer_managed_policy_attachments = []
      description                         = "ps-${each.value.namespace}-${each.value.group}"
      inline_policy                       = ""
      session_duration                    = "PT12H"
      relay_state                         = ""
    }
  ]
}

locals {
  value = module.permission_sets
}

locals {
  arns = tolist(data.aws_iam_roles.sso.arns)

  arns_without_path = [
    for parts in [for arn in data.aws_iam_roles.sso.arns : split("/", arn)] :
    format("%s/%s", parts[0], element(parts, length(parts) - 1))
  ]

  names = [
    for parts in [for arn in local.arns : split("_", arn)] :
    join("_", slice(parts, 1, length(parts) - 1))
  ]
}

data "aws_iam_roles" "sso" {
  depends_on = [module.permission_sets]
  name_regex = "AWSReservedSSO_.*"
}

#resource "aws_ssoadmin_permission_set" "DevOps_DevEnv" {
#  instance_arn = tolist(data.aws_ssoadmin_instances.this.arns)[0]
#  name         = "DevOps_DevEnv"
#  description  = "Provides access for members of the DevOps team to the development env"
#  tags = {
#    Environment = "Development"
#  }
#}
