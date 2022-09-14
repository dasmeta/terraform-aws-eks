data "aws_ssoadmin_instances" "this" {}

resource "aws_ssoadmin_permission_set" "this" {
  session_duration = "PT12H"
  for_each         = { for kr in var.bindings : "${kr.namespace}-${kr.group}" => kr }
  name             = "ps-${each.value.namespace}-${each.value.group}"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each           = { for kr in var.bindings : "${kr.namespace}-${kr.group}" => kr }
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess" #Configure
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
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
