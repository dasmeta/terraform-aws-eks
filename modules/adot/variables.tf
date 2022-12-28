variable "cluster_name" {
  type = string
}


variable "eks_oidc_root_ca_thumbprint" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "adot_version" {
  description = "The version of the AWS Distro for OpenTelemetry addon to use."
  type        = string
  default     = "v0.58.0-eksbuild.1"
}

variable "namespace" {
  description = "The namespace to install the AWS Distro for OpenTelemetry addon."
  type        = string
  default     = "adot"
}

variable "adot_collector_policy_arns" {
  description = "List of IAM policy ARNs to attach to the ADOT collector service account."
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  ]
}

variable "adot_config" {
  type = any
  default = {
    drop_namespace_regex = "(cert-manager)"
    additional_metrics   = {}
  }
}
