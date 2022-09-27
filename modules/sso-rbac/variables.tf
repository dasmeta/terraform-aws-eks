variable "bindings" {
  description = "Bindings to bind namespace and roles and then pass to kubernetes objects"
  type = list(object({
    group     = string
    namespace = string
    roles     = list(string)

  }))
}

variable "roles" {
  description = "Roles to provide kubernetes object"
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
}

variable "eks_module" {
  description = "terraform-aws-eks module to used for aws-auth update"
  type        = any
}

variable "account_id" {
  description = "Account Id to apply changes into"
  type        = string
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
