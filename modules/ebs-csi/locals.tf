locals {
  addon_name = "aws-ebs-csi-driver"
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))
}
