variable "priority_class" {
  type        = list(any)
  description = "Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high', 'medium' and 'low' . You can also provide a custom list of Priority Classes if needed."
  default     = [{}]
}
