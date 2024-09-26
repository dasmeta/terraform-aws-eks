locals {
  priority_class_default = [
    {
      name  = "high"
      value = "1000000"
    },
    {
      name  = "medium"
      value = "500000"
    },
    {
      name  = "low"
      value = "250000"
    }
  ]
  priority_class = concat(local.priority_class_default, var.additional_priority_classes)
}

output "priority_class" {
  value = local.priority_class
}

resource "kubernetes_priority_class" "this" {
  # Transform the list of maps into a key-value map suitable for for_each
  for_each = { for pc in local.priority_class : pc.name => pc }

  metadata {
    name = each.key
  }

  value = each.value.value
}
