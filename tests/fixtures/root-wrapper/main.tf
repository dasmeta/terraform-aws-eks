# Wraps the real root module so `terraform test` can plan it.
#
# Pointing a run block's module at the repository root makes the root's own outputs ROOT outputs, and
# Terraform then rejects `cluster_token` for carrying a sensitive value without being annotated. Annotating
# it would propagate sensitivity to every consumer's outputs, so it is not a change to make for a test.
# Consuming the module here -- which is how it is actually used -- keeps those as child outputs and plans
# the real code with no copies to drift.

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc" {
  type = any
}

variable "node_groups" {
  type = any
}

variable "karpenter" {
  type = any
}

module "this" {
  source = "../../.."

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc             = var.vpc
  node_groups     = var.node_groups
  karpenter       = var.karpenter
}
