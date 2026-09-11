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
  # selected by nodeClassRef name, so a pool referencing "protected" inherits the protected requirements,
  # taints, weight, disruption and limits without restating any of them.
  defaultEc2NodeClassProtected = {
    tags                = var.tags
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    amiSelectorTerms = coalesce(
      var.resource_configs_defaults["protected"].nodeClass.amiSelectorTerms,
      [{ alias = coalesce(
        var.resource_configs_defaults["protected"].nodeClass.amiAlias,
        var.resource_configs_defaults["default"].nodeClass.amiAlias,
        "al2023@latest"
      ) }]
    )
    detailedMonitoring  = var.resource_configs_defaults["protected"].nodeClass.detailedMonitoring
    metadataOptions     = var.resource_configs_defaults["protected"].nodeClass.metadataOptions
    blockDeviceMappings = var.resource_configs_defaults["protected"].nodeClass.blockDeviceMappings
  }

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

  nodePoolDefaultNodeClassRef = var.resource_configs_defaults["default"].nodeClassRef
  nodePoolDefaultRequirements = var.resource_configs_defaults["default"].requirements

  # Which defaults preset a pool inherits, resolved once: the node class it references, or "default".
  poolDefaultsKey = {
    for key, value in try(var.resource_configs.nodePools, {}) :
    key => contains(keys(var.resource_configs_defaults), try(value.template.spec.nodeClassRef.name, "default")) ? try(value.template.spec.nodeClassRef.name, "default") : "default"
  }

  # `weight` and `taints` exist on the protected preset and not on the others, so they must be ABSENT rather
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
        spec = merge({ nodeClassRef = local.nodePoolDefaultNodeClassRef }, try(value.template.spec, {}),
          # Same treatment: the protected preset carries taints, the others do not, and a pool that declares
          # its own keeps exactly what it wrote.
          { for k, v in { taints = local.poolOptional[key].taints } : k => v if v != null },
          {
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
