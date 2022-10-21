resource "aws_cloudwatch_log_group" "test" {
  name              = "ingress-${aws_s3_bucket.ingress-logs-bucket.bucket}"
  retention_in_days = 365
}


//This module usage causes error in Terraform Cloud, as there is not Python. Set send_alb_logs to false to disable this momdule.
module "alb_logs_to_cloudwatch" {
  source = "./terraform-aws-alb-cloudwatch-logs-json"
  count  = var.send_alb_logs_to_cloudwatch ? 1 : 0

  account_id = var.account_id
  region     = var.region

  bucket_name    = aws_s3_bucket.ingress-logs-bucket.bucket
  log_group_name = aws_cloudwatch_log_group.test.name

  create_alarm = false
}

resource "aws_lambda_permission" "bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.alb_logs_to_cloudwatch.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingress-logs-bucket.arn
}

resource "aws_s3_bucket_notification" "logs" {
  bucket = aws_s3_bucket.ingress-logs-bucket.bucket
  depends_on = [
    aws_lambda_permission.bucket
  ]

  lambda_function {
    lambda_function_arn = module.alb_logs_to_cloudwatch.function_arn
    events              = ["s3:ObjectCreated:*"]
  }
}
