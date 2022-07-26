variable "account_id" {
  type        = string
  description = "AWS Account Id to apply changes into"
}

variable "region" {
  type        = string
  description = "AWS Region name."
}

variable "function_name" {
  type    = string
  default = ""
}

variable "bucket_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "memory_size" {
  description = "Memory size for Lambda function"
  type        = number
  default     = null
}

variable "timeout" {
  description = "Timeout for Lambda function"
  type        = number
  default     = null
}

variable "create_alarm" {
  type    = bool
  default = false
}
