variable "defaults" {
  type = object({
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
  })
  default     = {}
  description = "The defaults to use on created StorageClasses if no specific values set for defined fields. The parameters field will be merged with the StorageClass custom set parameters"
}

# NOTE: there is aws eks default created StorageClass named gp2, and it was had been set as default prior to k8s v1.30. Here we define a list of StorageClasses to create and here we have "ebs-gp2" named(we do not use "gp2" name to not have conflicts) storage class based on ebs-csi which basically provides same ability that eks created "gp2" one
# TODO: consider implementation to replace the aws eks default gp2 named storage class that it creates with "ebs-gp2" one, most possibly some day aws eks will no longer auto-create "gp2" named storage class by default
variable "configs" {
  type = any
  default = {
    ebs-gp3 = { default = true, parameters = { type = "gp3" } } # new generation general purpose SSD, the default storage class with "gp3" volume types to use, baseline performance is 3000 IOPS and 125 MiB/s throughput, gp3 supports up to 1000 MB/s and 16,000 IOPS but there will be need to create separate StorageClass to utilize this with considering that in this case volume size have to satisfy the rule IOPS ≤ 500 × size(GiB) and that extra iops will be charged in separate if exceeds baseline
    ebs-gp2 = { parameters = { type = "gp2" } }                 # old generation general purpose SSD, this class we create as replacement of aws eks default created "gp2" StorageClass, Baseline is 3 IOPS per GiB (3 × volume GiBs) of volume size with minimum 100 IOPS and up to 16,000 IOPS . throughput for ≤ 170 GiB is max ~128 MiB/s; can reaches 250 MiB/s only ≥ 334 GiB; and 170–334 GiB can burst to 250 MiB/s
    # predefined set of the "io2" volume type StorageClasses with set/provisioned iops, this are SSDs with provision IOPS explicitly (good for latency-sensitive DBs),
    # NOTE: you pay also for the IOPS number you set (even if you don’t use them), so make sure you know your ipos requirement when setting
    ebs-io2-3k  = { parameters = { type = "io2", iops = "3000" } }
    ebs-io2-5k  = { parameters = { type = "io2", iops = "5000" } }
    ebs-io2-8k  = { parameters = { type = "io2", iops = "8000" } }
    ebs-io2-16k = { parameters = { type = "io2", iops = "16000" } }
    ebs-io2-32k = { parameters = { type = "io2", iops = "32000" } }
    ebs-io2-64k = { parameters = { type = "io2", iops = "64000" } }
    ebs-st1     = { parameters = { type = "st1" } } # the "st1" type, throughput-optimized HDD, designed for large, sequential I/O (big scans, ETL, log processing, data lakes)
    ebs-sc1     = { parameters = { type = "sc1" } } # the "sc1" type, cold HDD, lowest cost per GiB, lowest baseline throughput; for infrequently accessed, large, sequential data (cold logs, archives)
  }
  description = "The predefined {name}=>{configs} list/map of eks StorageClasses to create by default for ebs csi driver (the {configs} can have all var.defaults fields defined/customized here), if needed customization or additional StorageClasses the var.extra_configs can be used instead of changing this variable default"
}

variable "extra_configs" {
  type        = any
  default     = {}
  description = "The eks additional StorageClasses to create/configure. This is similar to var.configs object"
}
