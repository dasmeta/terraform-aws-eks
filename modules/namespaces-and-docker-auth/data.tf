data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}
