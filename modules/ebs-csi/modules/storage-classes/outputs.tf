output "storage_classes_configs" {
  value       = local.storage_classes
  description = "The final/prepared StorageClasses configs that will be used to create resources"
}

output "storage_classes_created" {
  value       = kubernetes_storage_class_v1.this
  description = "The created StorageClasses resources output data"
}
