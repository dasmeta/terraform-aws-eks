variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for addon"
}

variable "oidc_provider_arn" {
  type        = string
  description = "Cluster OIDC arn for policy configuration in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'"
}

variable "addon_version" {
  type        = string
  default     = null
  description = "Version of S3-CSI driver to use, if not passed the latest compatible version will be set based on cluster_version and most_recent"
}

variable "cluster_version" {
  type        = string
  default     = "1.30"
  description = "Version of eks cluster"
}

variable "most_recent" {
  type        = bool
  default     = true
  description = "Whether to use addon latest compatible version"
}

variable "s3_buckets" {
  type        = list(string)
  default     = []
  description = "The list of aws s3 bucket to which we will need to have access from inside eks cluster by using bucket mount as volume. NOTE: if no bucket passed then full access to s3 buckets being used"
}

variable "namespace" {
  description = "The namespace where addon pods getting placed."
  type        = string
  default     = "kube-system"
}

variable "serviceAccount" {
  description = "The name of eks service account."
  type        = string
  default     = "s3-csi-driver-sa"
}

variable "region" {
  type        = string
  default     = null
  description = "AWS Region, if not set the region will be fetched from provider/caller current context"
}

variable "configs" {
  type = any
  default = {
    node : {
      tolerateAllTaints : true
    }
  }
  description = "Pass additional addon config and override default ones"
}
