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
