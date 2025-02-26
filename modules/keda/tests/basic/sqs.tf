resource "aws_sqs_queue" "worker_queue" {
  name                       = "worker-queue"
  visibility_timeout_seconds = 30
}
