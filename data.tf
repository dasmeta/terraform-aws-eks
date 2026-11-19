data "aws_caller_identity" "current" {
  count = var.account_id == null ? 1 : 0
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

# AWS publishes no Amazon Linux 2 EKS AMI after Kubernetes 1.32. Without this guard a version bump on a setup
# that still declares an AL2_* ami_type is accepted at plan, upgrades the control plane, and only then fails on
# the node group update -- leaving the cluster half upgraded. Failing the plan keeps the cluster untouched.
# The guard sits on a data source so it adds nothing to state.
data "aws_partition" "ami_type_guard" {
  lifecycle {
    precondition {
      condition     = length(local.al2_ami_types_in_use) == 0 || tonumber(split(".", var.cluster_version)[1]) <= 32
      error_message = "cluster_version ${var.cluster_version} has no Amazon Linux 2 AMI, but these are still configured: ${join(", ", local.al2_ami_types_in_use)}. Move them to an AL2023_* (or BOTTLEROCKET_*) ami_type before upgrading."
    }
  }
}
