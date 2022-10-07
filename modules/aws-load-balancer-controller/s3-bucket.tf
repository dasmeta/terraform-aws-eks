resource "aws_s3_bucket" "ingress-logs-bucket" {
  bucket = var.alb_log_bucket_name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.alb_log_bucket_name}/${var.alb_log_bucket_path}/AWSLogs/${var.account_id}/*"
    }
  ]
}
POLICY

  tags = merge({
    BucketIdentity = "${var.alb_log_bucket_name}/${var.alb_log_bucket_path} ingress logs bucket" },
    var.tags
  )
}
