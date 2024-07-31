locals {
  default_storage_classes = [
    {
      name : "efs-sc"
      provisioning_mode : "efs-ap"
      file_system_id : var.efs_id
      directory_perms : "755"
      base_path : "/eks"
      uid : null
    },
    {
      name : "efs-sc-root"
      provisioning_mode : "efs-ap"
      file_system_id : var.efs_id
      directory_perms : "755"
      base_path : "/eks-root"
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
      provisioningMode = each.value.provisioning_mode
      fileSystemId     = each.value.file_system_id
      directoryPerms   = each.value.directory_perms
      basePath         = each.value.base_path
    },
    each.value.uid != null ? { "uid" : each.value.uid } : {}
  )
}
