locals {
  amiFamilyGpu = "AL2023"

  # Controller resources. Built explicitly rather than passed straight through so that an unset cpu limit stays
  # absent from the rendered values instead of appearing as null, which helm would render as an empty limit.
  controller_resources = {
    requests = {
      cpu    = var.controller_resources.requests.cpu
      memory = var.controller_resources.requests.memory
    }
    limits = merge(
      var.controller_resources.limits.memory != null ? { memory = var.controller_resources.limits.memory } : {},
      var.controller_resources.limits.cpu != null ? { cpu = var.controller_resources.limits.cpu } : {},
    )
  }

  # We create this aws ec2 node class as default for karpenter as this is something general and can be used as default for node-pools which have not nodeClassRef required field set explicitly
  defaultEc2NodeClass = {
    tags                = var.tags
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    # Declarative alias selection. `amiFamily` is implied by the alias family, so it is not set alongside it.
    # This replaces deriving the AMI from an arbitrary running instance, which allowed an unrelated apply to
    # change the fleet's target image and mark every node drifted at once.
    # An explicit amiSelectorTerms override wins over the alias.
    amiSelectorTerms = coalesce(
      var.resource_configs_defaults["default"].nodeClass.amiSelectorTerms,
      [{ alias = coalesce(var.resource_configs_defaults["default"].nodeClass.amiAlias, "al2023@latest") }]
    )
    detailedMonitoring  = var.resource_configs_defaults["default"].nodeClass.detailedMonitoring
    metadataOptions     = var.resource_configs_defaults["default"].nodeClass.metadataOptions
    blockDeviceMappings = var.resource_configs_defaults["default"].nodeClass.blockDeviceMappings
  }

  # Identical in shape to the default class. It exists as its own class because the defaults preset is
  # selected by nodeClassRef name, so a pool referencing "on-demand" inherits that preset's requirements,
  # taints, weight, disruption and limits without restating any of them.
  # amiFamily is REQUIRED by the CRD whenever amiSelectorTerms carries an `id` rather than an `alias`: with
  # an alias the family is implied, with a raw id karpenter cannot infer the bootstrap format and rejects the
  # class with "must specify amiFamily if amiSelectorTerms does not contain an alias". That rejection happens
  # server-side on APPLY, so a plan looks clean and the failure only appears when the helm release patches.
  #
  # Emitted only when set, via a for-expression rather than a ternary: a rendered `amiFamily: null` is not
  # the same as the field being absent, and the alias form must not carry one.
  # Whether to derive the on-demand AMI from the managed node groups. False as soon as the consumer pinned
  # the class themselves, which also skips the lookups in data.tf. Both inputs are variables, so this is
  # known at plan time and can gate a count.
  onDemandAmiAuto = (
    var.resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms == null &&
    var.resource_configs_defaults["on-demand"].nodeClass.amiAlias == null
  )

  # Read off the image we actually found, NOT from configuration. The two can disagree -- a node group may
  # override ami_type while node_groups_default says something else -- and a node booted with the wrong
  # family gets the wrong bootstrap. Deriving both from the same AMI makes that impossible.
  onDemandAmiFamilyDerived = local.onDemandAmiAuto ? (
    (strcontains(data.aws_ami.managed_node[0].name, "al2023") || strcontains(data.aws_ami.managed_node[0].description, "Amazon Linux 2023")) ? "AL2023" :
    (strcontains(lower(data.aws_ami.managed_node[0].name), "bottlerocket")) ? "Bottlerocket" :
    (strcontains(data.aws_ami.managed_node[0].name, "amzn2") || strcontains(data.aws_ami.managed_node[0].description, "AmazonLinux2")) ? "AL2" :
    "AL2023"
  ) : null

  # amiFamily is MANDATORY whenever amiSelectorTerms carries an id rather than an alias: the CRD rejects the
  # class with "must specify amiFamily if amiSelectorTerms does not contain an alias". It rejects it on
  # APPLY, not at plan, so a missing family surfaces when the helm release patches rather than in review.
  # Key presence is decided by config-known conditions so the rendered object's shape never depends on a
  # value that is only known after apply.
  defaultEc2NodeClassOnDemandAmiFamily = (
    var.resource_configs_defaults["on-demand"].nodeClass.amiFamily != null
    ? { amiFamily = var.resource_configs_defaults["on-demand"].nodeClass.amiFamily }
    : local.onDemandAmiAuto ? { amiFamily = local.onDemandAmiFamilyDerived } : {}
  )

  defaultEc2NodeClassOnDemand = merge(local.defaultEc2NodeClassOnDemandAmiFamily, {
    tags                = var.tags
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    # The derived pin only applies when the consumer set neither AMI field. Their own amiSelectorTerms wins
    # outright; their own amiAlias falls through to the alias branch below. Checked in that order because the
    # submodule prefers amiSelectorTerms, so injecting a derived one would silently beat a consumer's alias.
    amiSelectorTerms = (
      var.resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms != null
      ? var.resource_configs_defaults["on-demand"].nodeClass.amiSelectorTerms
      : local.onDemandAmiAuto
      ? [{ id = data.aws_instance.managed_node[0].ami }]
      : [{ alias = coalesce(
        var.resource_configs_defaults["on-demand"].nodeClass.amiAlias,
        var.resource_configs_defaults["default"].nodeClass.amiAlias,
        "al2023@latest"
      ) }]
    )
    detailedMonitoring  = var.resource_configs_defaults["on-demand"].nodeClass.detailedMonitoring
    metadataOptions     = var.resource_configs_defaults["on-demand"].nodeClass.metadataOptions
    blockDeviceMappings = var.resource_configs_defaults["on-demand"].nodeClass.blockDeviceMappings
  })

  defaultEc2NodeClassGpu = {
    tags                = var.tags
    amiFamily           = coalesce(var.resource_configs_defaults["gpu"].nodeClass.amiFamily, local.amiFamilyGpu) # ami family should be get automatically, but it can be also passed for node class
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    amiSelectorTerms = [
      { id = data.aws_ami.gpu.id }
    ]
    detailedMonitoring  = var.resource_configs_defaults["gpu"].nodeClass.detailedMonitoring
    metadataOptions     = var.resource_configs_defaults["gpu"].nodeClass.metadataOptions
    blockDeviceMappings = var.resource_configs_defaults["gpu"].nodeClass.blockDeviceMappings
  }


  # Which defaults preset a pool inherits, resolved once: the node class it references, or "default".
  #
  # A class name matching no preset falls back to "default", which is what a consumer's own custom node
  # class should do.
  poolDefaultsKey = {
    for key, value in try(var.resource_configs.nodePools, {}) :
    key => contains(keys(var.resource_configs_defaults), try(value.template.spec.nodeClassRef.name, "default")) ? try(value.template.spec.nodeClassRef.name, "default") : "default"
  }

  # `weight` and `taints` exist on the on-demand preset and not on the others, so they must be ABSENT rather
  # than null for pools that have neither -- a rendered `weight: null` is not the same thing as no weight.
  # Resolved here, then merged in below only when set.
  poolOptional = {
    for key, value in try(var.resource_configs.nodePools, {}) : key => {
      weight = try(value.weight, try(var.resource_configs_defaults[local.poolDefaultsKey[key]].weight, null))
      taints = try(value.template.spec.taints, try(var.resource_configs_defaults[local.poolDefaultsKey[key]].taints, null))
    }
  }

  nodePools = { for key, value in try(var.resource_configs.nodePools, {}) : key => merge(
    value,
    # Dropped entirely when null. Built as a for-expression over a single-entry object rather than a
    # ternary: a ternary would have to unify `{ weight = number }` with `{}`, which terraform rejects as
    # inconsistent result types -- and it rejects it at plan time, not at validate, so it would reach
    # consumers. The same shape is used for the system node group taint in the root module.
    { for k, v in { weight = local.poolOptional[key].weight } : k => v if v != null },
    {
      template = merge(try(value.template, {}), {
        spec = merge(try(value.template.spec, {}),
          # Same treatment: the on-demand preset carries taints, the others do not, and a pool that declares
          # its own keeps exactly what it wrote.
          { for k, v in { taints = local.poolOptional[key].taints } : k => v if v != null },
          {
            # DEEP merge, unlike everything else in this spec. merge() is shallow, so a pool supplying only
            # `nodeClassRef = { name = "on-demand" }` -- which is the documented way to select a preset --
            # would otherwise REPLACE the whole reference and drop `group` and `kind`. The CRD requires both,
            # so the NodePool is rejected at apply time with "nodeClassRef.group: Required value", long after
            # the plan looked fine. Merging over the selected preset's own reference fills them in, and a
            # name matching no preset still gets a usable group/kind from the default one.
            nodeClassRef = merge(
              var.resource_configs_defaults[local.poolDefaultsKey[key]].nodeClassRef,
              try(value.template.spec.nodeClassRef, {})
            )
            requirements           = concat([for item in var.resource_configs_defaults[local.poolDefaultsKey[key]].requirements : item if !contains(try(value.template.spec.requirements, []).*.key, item.key)], try(value.template.spec.requirements, []))
            expireAfter            = try(value.template.spec.expireAfter, var.resource_configs_defaults[local.poolDefaultsKey[key]].expireAfter)
            terminationGracePeriod = try(value.template.spec.terminationGracePeriod, var.resource_configs_defaults[local.poolDefaultsKey[key]].terminationGracePeriod)
        })
      })
      # A pool's own disruption settings win field by field over the class defaults, which already carry any
      # protection windows as ordinary budget entries. There is no append step and therefore no
      # append-versus-override ambiguity: a pool that declares budgets simply has them.
      disruption = merge(
        var.resource_configs_defaults[local.poolDefaultsKey[key]].disruption,
        try(value.disruption, {}),
      )
      limits = merge(var.resource_configs_defaults[local.poolDefaultsKey[key]].limits, try(value.limits, {}))
    }
  ) }

}
