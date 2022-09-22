variable "bindings" {
  type = list(object({
    group     = string
    namespace = string
    roles     = list(string)

  }))
}

variable "roles" {
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
}

variable "eks_module" {
  type = any
}

variable "account_id" {
  type = string
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)
  default     = []
}
