variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for addon"
}

variable "cluster_oidc_arn" {
  type        = string
  description = "Cluster OIDC arn for policy configuration"
}

variable "addon_version" {
  type        = string
  default     = null
  description = "Version of EBS-CSI driver to use, if not passed the latest compatible version will be set based on cluster_version and most_recent"
}

variable "cluster_version" {
  type        = string
  default     = "1.32"
  description = "Version of eks cluster"
}

variable "most_recent" {
  type        = bool
  default     = false
  description = "Whether to use addon latest compatible version"
}

variable "storage_classes" {
  type = object({
    defaults = optional(object({                                        # defaults to pass StorageClass
      enabled                = optional(bool, true)                     # whether storage class enabled
      default                = optional(bool, false)                    # whether storage class is default
      storage_provisioner    = optional(string, "ebs.csi.aws.com")      # provisioner to use for storage class
      volume_binding_mode    = optional(string, "WaitForFirstConsumer") # when volume binding and dynamic provisioning should occur
      allow_volume_expansion = optional(bool, true)                     # whether the storage class allow volume expand
      reclaim_policy         = optional(string, "Retain")               # whether to "Retain" or "Delete" pv on pvc removal
      mount_options          = optional(list(string), [])               # mount options to set, for example ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
      parameters = optional(object({
        fsType    = optional(string, "ext4") # the filesystem of the volume
        encrypted = optional(string, "true") # whether to have storage encrypted
        kmsKeyId  = optional(string, null)   # the custom kms key to pass to encrypt storage when encrypted=true, by default aws managed key will be used
      }), {})
    }), {})
    extra_configs = optional(any, {}) # the map of {class-name}=>{class-configs} to customize predefined ones or create additional StorageClasses, the {class-configs} object has same field as var.storage_classes.defaults
  })
  default     = {}
  description = "The eks ebs-csi StorageClasses to create/configure. We have predefined StorageClasses: ebs-gp3, ebs-gp2, ebs-io2-3k, ebs-io2-5k, ebs-io2-8k, ebs-io2-16k, ebs-io2-32k, ebs-io2-64k, ebs-st1 and ebs-sc1. This ones can be customized or extended with additional ones by using var.storage_classes.extra_configs"
}
