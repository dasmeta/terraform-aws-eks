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

  nodePools = { for key, value in try(var.resource_configs.nodePools, {}) : key => merge(
    value,
    {
      template = merge(try(value.template, {}), {
        spec = merge({ nodeClassRef = local.nodePoolDefaultNodeClassRef }, try(value.template.spec, {}), {
          requirements           = concat([for item in var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].requirements : item if !contains(try(value.template.spec.requirements, []).*.key, item.key)], try(value.template.spec.requirements, []))
          expireAfter            = try(value.template.spec.expireAfter, var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].expireAfter)
          terminationGracePeriod = try(value.template.spec.terminationGracePeriod, var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].terminationGracePeriod)
        })
      })
      # A pool's own disruption settings win field by field over the class defaults, which already carry any
      # protection windows as ordinary budget entries. There is no append step and therefore no
      # append-versus-override ambiguity: a pool that declares budgets simply has them.
      disruption = merge(
        var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].disruption,
        try(value.disruption, {}),
      )
      limits = merge(var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].limits, try(value.limits, {}))
    }
  ) }

}
