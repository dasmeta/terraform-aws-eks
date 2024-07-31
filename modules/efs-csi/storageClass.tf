locals {
  default_storage_classes = [
    {
      name : "efs-sc"
      file_system_id : var.efs_id
      directory_perms : "755"
      base_path : "/eks"
      uid : null
    },
    {
      name : "efs-sc-root"
      file_system_id : var.efs_id
      directory_perms : "755"
      base_path : "/eks"
      uid : 0
    }
  ]

  combined_storage_classes = concat(local.default_storage_classes, var.storage_classes)
}


resource "kubernetes_storage_class" "efs_storage_class" {
  for_each = { for sc in local.combined_storage_classes : sc.name => sc }

  metadata {
    name = each.value.name
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = merge(
    {
      provisioningMode = "efs-ap"
      fileSystemId     = each.value.file_system_id
      directoryPerms   = each.value.directory_perms
      basePath         = coalesce(each.value.base_path, "/eks")
    },
    each.value.uid != null ? { "uid" : each.value.uid } : {}
  )
}
