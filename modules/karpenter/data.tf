# The AMI the EKS managed node groups are running, for the ON-DEMAND pool only.
#
# EKS resolves a managed node group's AMI once at create or update and the group then stays on it, so managed
# nodes have never rolled on an AWS AMI release. The on-demand pool holds the workloads that must not be
# replaced on somebody else's schedule, so it needs the same property. An `al2023@latest` alias is
# re-evaluated continuously and cannot provide it: every AWS AMI release drifts the pool.
#
# The spot pool keeps the alias deliberately -- tracking the newest image is fine for capacity that is
# already interruptible, and it gets the new image during its own disruption window.
#
# These lookups live HERE rather than at the root on purpose. The module call carries depends_on, which
# defers every data source in the module until after the node groups exist, so a first create resolves the
# pin in a single apply. Moving them to the root means they resolve during plan, before any node group
# exists, which needs a second apply to pick up the pin.

# Skipped entirely when the consumer pinned the on-demand class themselves -- no reads, nothing to fail.
# Both conditions come from a variable, so the counts are known at plan time.
data "aws_instances" "managed_nodes" {
  count = local.onDemandAmiAuto ? 1 : 0

  instance_state_names = ["running"]

  # EKS's own tags, not our karpenter.sh/discovery tag. Ours does reach these instances, but EKS's cannot be
  # broken by a change to how we propagate ours, and they can never match a karpenter-provisioned node --
  # which would make the lookup circular.
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag-key"
    values = ["eks:nodegroup-name"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) > 0
      error_message = <<-EOT
        No running EKS managed node group instance was found for cluster "${var.cluster_name}", so the
        on-demand karpenter pool's AMI cannot be derived from one.

        Karpenter cannot run on a cluster in this state anyway: its controller is not schedulable onto
        karpenter-provisioned nodes, so it needs at least one managed node group with running instances.

        Either give the cluster a managed node group (var.node_groups), or pin the pool explicitly with
        karpenter.resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms, which skips this
        lookup. The explicit pin is also the route for a cluster whose nodes come from var.worker_groups,
        since self-managed instances do not carry the EKS node group tags this filter matches.
      EOT
    }
  }
}

data "aws_instance" "managed_node" {
  count = local.onDemandAmiAuto ? 1 : 0

  # sort(), not ids[0]. DescribeInstances returns instances in AWS's order, not a sorted one, so taking the
  # first of the raw list means the same set of instances can yield a different AMI from one apply to the
  # next and flip the pin back and forth. Sorting makes one set give one answer, always.
  #
  # One instance is enough: every node in a settled group runs the same AMI. While a group is mid-roll two
  # AMIs are briefly present and which one sorts first is arbitrary -- instance ids are random, not ordered
  # by age -- so an apply during a roll may move the pin. The pool's Drifted budget gates the consequence to
  # outside working hours, and once the roll finishes there is only one AMI left to find.
  instance_id = sort(data.aws_instances.managed_nodes[0].ids)[0]
}

data "aws_ami" "managed_node" {
  count = local.onDemandAmiAuto ? 1 : 0

  # No owners filter. The image-id below is one we just observed on a running node, which is authoritative
  # on its own, and a managed node group may legitimately run a customer-owned image (per-group ami_id) that
  # an official-account filter would exclude -- failing the lookup on a supported configuration.
  filter {
    name   = "image-id"
    values = [data.aws_instance.managed_node[0].ami]
  }
}

data "aws_ami" "gpu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-nvidia-${var.cluster_version}-*"]
  }
  # Only EKS official AMIs are owned by AWS account 602401143452
  owners = ["602401143452"]
}
