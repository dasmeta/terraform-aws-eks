variable "additional_priority_classes" {
  type = list(object({
    name  = string
    value = string # number in string form
  }))
  description = "Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high'(1000000), 'medium'(500000) and 'low'(250000) . You can also provide a custom list of Priority Classes if needed."
  default     = []
}
