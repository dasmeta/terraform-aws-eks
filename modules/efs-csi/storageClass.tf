resource "kubernetes_storage_class" "efs-storage-class" {
  metadata {
    name = "efs-sc"
  }
  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode : "efs-ap"
    fileSystemId : var.efs_id
    directoryPerms : "755"
    basePath : "/eks"
    uid : "0"
  }
}
