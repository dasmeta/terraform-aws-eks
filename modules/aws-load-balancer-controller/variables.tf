variable "account_id" {
  type        = string
  description = "AWS Account Id to apply changes into"
}

variable "region" {
  type        = string
  description = "AWS Region name."
}

// s3 bucket configs for ALB
data "aws_elb_service_account" "main" {}

variable "cluster_name" {
  type        = string
  default     = ""
  description = "eks cluster name"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "namespace load balancer controller should be deployed into"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "wether or no to create namespace"
}

variable "eks_oidc_root_ca_thumbprint" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

## the load balancer access logs sync to s3=>lambda=>cloudwatch was disabled/commented-out so this params also need/can be commented,
## after then the fix be applied for enabling this functionality we can uncomment them

# variable "create_alb_log_bucket" {
#   type        = bool
#   default     = false
#   description = "wether or no to create alb s3 logs bucket"
# }

# variable "send_alb_logs_to_cloudwatch" {
#   type        = bool
#   default     = true
#   description = "Whether send alb logs to CloudWatch or not."
# }

# variable "alb_log_bucket_name" {
#   type    = string
#   default = "ingress-logs-bucket"
# }

# variable "alb_log_bucket_path" {
#   type    = string
#   default = ""
# }

variable "tags" {
  description = "A mapping of tags to assign to the object."
  type        = any
  default     = null
}

variable "enable_waf" {
  type        = bool
  description = "Enables WAF and WAF V2 addons for ALB"
  default     = false
}

variable "chart_version" {
  type        = string
  default     = "1.10.1"
  description = "The app chart version"
}
