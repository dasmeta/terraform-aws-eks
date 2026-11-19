output "priority_class" {
  value = local.priority_class
}

output "priority_class_map" {
  value = { for pc in local.priority_class : pc.name => pc }
}

output "created_names" {
  # Read from the created objects rather than the locals, so a consumer referencing it is ordered after the
  # priority classes exist in the cluster -- which a reference to priority_class_map does not give.
  value       = [for pc in kubernetes_priority_class.this : pc.metadata[0].name]
  description = "Names of the priority classes as created in the cluster. Reference this to order something after they exist."
}
