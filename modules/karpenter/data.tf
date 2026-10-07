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
  # Only instances whose architecture the on-demand pools accept. Without this an ARM managed group -- or an
  # ARM instance that happens to sort first in a mixed cluster -- would pin an ARM image into a class whose
  # pools require amd64, leaving karpenter no compatible image/instance pair and protected pods Pending.
  filter {
    name   = "architecture"
    values = local.onDemandEc2Archs
  }

  lifecycle {
    precondition {
      condition     = length(local.onDemandEc2Archs) > 0
      error_message = <<-EOT
        The node pools that reference the on-demand node class require architectures with nothing in
        common, so no single pinned image can serve them all.

        One image has exactly one architecture, and every pool using this class gets that image. Give the
        pools a common kubernetes.io/arch, move the odd one to its own node class, or pin this class
        explicitly with karpenter.resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms.
      EOT
    }

    postcondition {
      condition     = length(self.ids) > 0
      error_message = <<-EOT
        No running EKS managed node group instance of architecture ${join("/", local.onDemandEc2Archs)} was
        found for cluster "${var.cluster_name}", so the on-demand karpenter pool's AMI cannot be derived from one.

        The architecture comes from the kubernetes.io/arch requirement of the pools using the on-demand node
        class. If the managed node groups run a different architecture, either align them or pin the class
        explicitly as below.

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
  #
  # SUPPORTED SHAPE: ONE managed node group, which hosts the karpenter controller and the cluster's own
  # components while workloads run on karpenter nodes (see var.node_groups). With several managed groups on
  # different AMIs, replacing or scaling an instance can change which id sorts first and so move the pin on
  # an unrelated apply. That is an accepted gap, not a new one: before 3.0.0 this took an UNSORTED ids[0]
  # across every instance in the cluster. A cluster with more than one managed node group should pin the
  # class explicitly with resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms.
  instance_id = sort(data.aws_instances.managed_nodes[0].ids)[0]
}

data "aws_ami" "managed_node" {
  count = local.onDemandAmiAuto ? 1 : 0

  # Selection is by exact image-id read off an instance already running in this cluster, so there is no set
  # to choose from. owners is here as a trust assertion rather than a selector: it fails the lookup loudly if
  # the managed nodes are ever running an image from outside these accounts, instead of adopting it silently.
  #
  # SUPPORTED SCOPE, deliberately: managed node groups on the official Amazon EKS optimized AMIs, in
  # commercial regions. That is all this module has ever documented or offered -- no input, example or guide
  # covers a custom node group image -- and the gpu lookup below has carried this same owner since before
  # 3.0.0, so other partitions were never supported either.
  #
  #   602401143452  the official Amazon EKS optimized AMI account for commercial regions
  #   self          tolerated so an image built in this account does not hard-fail; not a support commitment
  #
  # Outside that scope -- an image shared from a central image account, or GovCloud/China where EKS
  # publishes under different accounts -- pin the class explicitly with
  # resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms, which skips this lookup entirely.
  owners = ["602401143452", "self"]

  filter {
    name   = "image-id"
    values = [data.aws_instance.managed_node[0].ami]
  }

  lifecycle {
    # Defence in depth behind the instance filter: never pin an image the pools cannot run.
    postcondition {
      condition     = contains(local.onDemandEc2Archs, self.architecture)
      error_message = "AMI ${self.id} is ${self.architecture}, but the pools using the on-demand node class accept only ${join("/", local.onDemandEc2Archs)}. Pin the class explicitly with karpenter.resource_configs_defaults[\"on-demand\"].nodeClass.amiSelectorTerms."
    }

    # No silent default family. The matchers are evaluated on self here, not through the derived local, so
    # the check cannot depend on the value it is checking.
    postcondition {
      condition = local.onDemandAmiFamilyOverride != null || anytrue([
        for m in local.amiFamilyMatchers : anytrue([
          for t in m.tokens : strcontains(lower(join(" ", [for x in [self.name, self.description] : x if x != null])), t)
        ])
      ])
      error_message = <<-EOT
        Cannot tell the bootstrap family of AMI ${self.id} ("${self.name}") from its name or description,
        which the managed node groups are running and the on-demand pool would be pinned to.

        Guessing would boot the pool with the wrong bootstrap, so set it explicitly:
        karpenter.resource_configs_defaults["on-demand"].nodeClass.amiFamily = "AL2023" | "AL2" | "Bottlerocket"
      EOT
    }
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
