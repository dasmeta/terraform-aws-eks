## This submodule allows to create/configure storage aws eks ebs-csi driver provisioner predefined/additional StorageClasses
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.23 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_storage_class_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_configs"></a> [configs](#input\_configs) | The predefined {name}=>{configs} list/map of eks StorageClasses to create by default for ebs csi driver (the {configs} can have all var.defaults fields defined/customized here), if needed customization or additional StorageClasses the var.extra\_configs can be used instead of changing this variable default | `any` | <pre>{<br/>  "ebs-gp2": {<br/>    "parameters": {<br/>      "type": "gp2"<br/>    }<br/>  },<br/>  "ebs-gp3": {<br/>    "default": true,<br/>    "parameters": {<br/>      "type": "gp3"<br/>    }<br/>  },<br/>  "ebs-io2-16k": {<br/>    "parameters": {<br/>      "iops": "16000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-io2-32k": {<br/>    "parameters": {<br/>      "iops": "32000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-io2-3k": {<br/>    "parameters": {<br/>      "iops": "3000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-io2-5k": {<br/>    "parameters": {<br/>      "iops": "5000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-io2-64k": {<br/>    "parameters": {<br/>      "iops": "64000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-io2-8k": {<br/>    "parameters": {<br/>      "iops": "8000",<br/>      "type": "io2"<br/>    }<br/>  },<br/>  "ebs-sc1": {<br/>    "parameters": {<br/>      "type": "sc1"<br/>    }<br/>  },<br/>  "ebs-st1": {<br/>    "parameters": {<br/>      "type": "st1"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_defaults"></a> [defaults](#input\_defaults) | The defaults to use on created StorageClasses if no specific values set for defined fields. The parameters field will be merged with the StorageClass custom set parameters | <pre>object({<br/>    enabled                = optional(bool, true)                     # whether storage class enabled<br/>    default                = optional(bool, false)                    # whether storage class is default<br/>    storage_provisioner    = optional(string, "ebs.csi.aws.com")      # provisioner to use for storage class<br/>    volume_binding_mode    = optional(string, "WaitForFirstConsumer") # when volume binding and dynamic provisioning should occur<br/>    allow_volume_expansion = optional(bool, true)                     # whether the storage class allow volume expand<br/>    reclaim_policy         = optional(string, "Retain")               # whether to "Retain" or "Delete" pv on pvc removal<br/>    mount_options          = optional(list(string), [])               # mount options to set, for example ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]<br/>    parameters = optional(object({<br/>      fsType    = optional(string, "ext4") # the filesystem of the volume<br/>      encrypted = optional(string, "true") # whether to have storage encrypted<br/>      kmsKeyId  = optional(string, null)   # the custom kms key to pass to encrypt storage when encrypted=true, by default aws managed key will be used<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_extra_configs"></a> [extra\_configs](#input\_extra\_configs) | The eks additional StorageClasses to create/configure. This is similar to var.configs object | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_storage_classes_configs"></a> [storage\_classes\_configs](#output\_storage\_classes\_configs) | The final/prepared StorageClasses configs that will be used to create resources |
| <a name="output_storage_classes_created"></a> [storage\_classes\_created](#output\_storage\_classes\_created) | The created StorageClasses resources output data |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
