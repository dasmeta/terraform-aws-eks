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
  merged_priority_class = concat(local.priority_class_default, var.priority_class)
  priority_class        = [for map in local.merged_priority_class : map if length(map) > 0]
}

output "priority_class" {
  value = local.priority_class
}

resource "kubernetes_priority_class" "example" {
  # Transform the list of maps into a key-value map suitable for for_each
  for_each = { for pc in local.priority_class : pc.name => pc }

  metadata {
    name = each.key
  }

  value = each.value.value
}
