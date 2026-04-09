output "priority_class" {
  value = local.priority_class
}

output "priority_class_map" {
  value = { for pc in local.priority_class : pc.name => pc }
}
