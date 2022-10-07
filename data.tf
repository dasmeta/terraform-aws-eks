data "aws_caller_identity" "current" {
  count = var.account_id == null ? 1 : 0
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}
