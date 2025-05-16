locals {
  addon_name = "aws-mountpoint-s3-csi-driver"

  mountpoint_s3_csi_bucket_arns = length(var.s3_buckets) > 0 ? data.aws_s3_bucket.this.*.arn : ["arn:aws:s3:::*"]
  mountpoint_s3_csi_path_arns   = [for item in local.mountpoint_s3_csi_bucket_arns : "${item}/*"]

  region = coalesce(var.region, try(data.aws_region.current[0].name, null))
}
