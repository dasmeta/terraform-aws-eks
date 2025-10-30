resource "kubernetes_storage_class_v1" "this" {
  for_each = { for key, value in local.storage_classes : key => value if value.enabled }

  metadata {
    name = each.key
    annotations = {
      "storageclass/managed-by"                     = "terraform"
      "storageclass.kubernetes.io/is-default-class" = each.value.default ? "true" : "false"
    }
  }

  storage_provisioner    = each.value.storage_provisioner
  parameters             = each.value.parameters
  volume_binding_mode    = each.value.volume_binding_mode
  allow_volume_expansion = each.value.allow_volume_expansion
  reclaim_policy         = each.value.reclaim_policy
  mount_options          = each.value.mount_options
}
