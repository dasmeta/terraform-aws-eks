data "aws_caller_identity" "current" {
  count = var.account_id == null ? 1 : 0
}

data "aws_region" "current" {
  count = var.region == null ? 1 : 0
}

# The AMI the EKS managed node groups are ACTUALLY running, so the on-demand karpenter pool can match it.
#
# EKS resolves a managed node group's AMI once at create or update and the group then stays on it -- the
# upstream module leaves ami_release_version unset and use_latest_ami_release_version defaults to false.
# That "resolve once, then stay" is why managed nodes have never rolled on an AWS AMI release, and the
# on-demand pool needs the same property: it holds the workloads that must not be replaced on somebody
# else's schedule. The al2023@latest alias is re-evaluated continuously and cannot provide it.
#
# There is no node group attribute to read this from. The EKS API reports a release_version
# ("1.35.8-20260930") and the upstream module does not output it, and turning one into an AMI id means
# rebuilding the image NAME per family and architecture -- a mapping whose failure mode is picking the wrong
# image, not failing. So the id comes from the instances themselves.
#
# ORDERING. for_each is keyed on var.node_groups, so the keys are known at plan time while only the filter
# value comes from a node group that does not exist yet on a first create. Terraform therefore DEFERS these
# reads to apply instead of resolving them empty, and one apply is enough. A for_each over discovered
# instance ids cannot do this -- unknown keys are a hard plan error -- which is why the first version of
# this read resolved at plan time and needed a second apply to pin the pool.
#
# Deliberately at the ROOT, not inside modules/karpenter. That module call carries
# depends_on = [module.eks-core-components, module.priority_class], and a module-level depends_on defers
# EVERY data source inside it whenever those have pending changes -- even ones that depend on nothing. The
# AMI would then go unknown on any addon change and churn the EC2NodeClass on plans that touch nothing to do
# with karpenter. Here the only dependency is the node group itself, so a plan churns when the node groups
# change and at no other time.
data "aws_instances" "managed_nodes" {
  for_each = local.karpenter_ami_lookup_node_groups

  instance_state_names = ["running"]

  # EKS's own tags, not our karpenter.sh/discovery tag. That tag does reach these instances, but keying on
  # EKS's cannot be broken by a change to how we propagate ours, and it can never match a
  # karpenter-provisioned node -- which would make the lookup circular.
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [local.karpenter_ami_lookup_node_group_names[each.key]]
  }
}

data "aws_instance" "managed_node" {
  for_each = local.karpenter_ami_lookup_node_groups

  # One instance per group is enough: every node in a group runs the same AMI except mid-roll, and the
  # most_recent below resolves that. Falls back to any other group's instance so a group sitting at
  # desired_size 0 does not fail the read.
  instance_id = try(
    data.aws_instances.managed_nodes[each.key].ids[0],
    local.managed_node_any_instance_id,
  )
}

# most_recent, not the first id. The pre-3.0.0 implementation took ids[0] from an unordered list, so while a
# group was mid-roll and running two AMIs the pick could flip between applies and drift the whole fleet.
# Resolving the newest of whatever is running is stable, and converges on the new image during a roll
# instead of oscillating.
data "aws_ami" "managed_node" {
  count = length(local.karpenter_ami_lookup_node_groups) > 0 ? 1 : 0

  most_recent = true
  owners      = ["602401143452"] # EKS official AMIs are owned by this AWS account

  filter {
    name   = "image-id"
    values = local.managed_node_ami_ids
  }
}
