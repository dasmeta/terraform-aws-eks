locals {
  region = coalesce(var.region, try(data.aws_region.current[0].name, null))
}
