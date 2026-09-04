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

  # Disruption budgets rendered from the configured protection windows. `nodes = "0"` for the listed reasons
  # means no voluntary disruption of that kind may start while the window is open. These never delay spot
  # interruption handling or node expiry, both of which bypass budgets entirely.
  disruption_window_budgets = [
    for window in var.disruption_windows : {
      nodes    = window.nodes
      schedule = window.schedule
      duration = window.duration
      reasons  = window.reasons
    }
  ]

  # We create this aws ec2 node class as default for karpenter as this is something general and can be used as default for node-pools which have not nodeClassRef required field set explicitly
  defaultEc2NodeClass = {
    tags                = var.tags
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    # Declarative alias selection. `amiFamily` is implied by the alias family and is therefore not set here.
    # This replaces deriving the AMI from an arbitrary running instance, which allowed an unrelated apply to
    # change the fleet's target image and mark every node drifted at once.
    amiSelectorTerms = [
      { alias = var.ami_alias }
    ]
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
          requirements = concat([for item in var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].requirements : item if !contains(try(value.template.spec.requirements, []).*.key, item.key)], try(value.template.spec.requirements, []))
          # expireAfter deliberately stays "Never": node expiry is NOT gated by disruption budgets, so a finite
          # value would replace nodes unpaced and outside var.disruption_windows. AMI patching is handled by
          # budget-paced drift via var.ami_alias instead.
          expireAfter            = try(value.template.spec.expireAfter, "Never")
          terminationGracePeriod = try(value.template.spec.terminationGracePeriod, var.termination_grace_period)
        })
      })
      # Budgets: a pool that declares its own budgets OWNS them completely and the module's disruption
      # windows are not appended. Appending would be worse than useless -- karpenter resolves multiple
      # budgets most-restrictive-wins, so a hand-tuned window (one production cluster already runs
      # 12:00 UTC for 16h, every day, matched to its own timezone) would silently gain a second, narrower
      # module window on top of it and the operator's intent would be quietly overridden.
      # Only pools that express no opinion get the module default plus its windows.
      disruption = merge(
        var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].disruption,
        try(value.disruption, {}),
        {
          budgets = try(value.disruption.budgets, null) != null ? value.disruption.budgets : concat(
            var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].disruption.budgets,
            local.disruption_window_budgets,
          )
        }
      )
      limits = merge(var.resource_configs_defaults[try(value.template.spec.nodeClassRef.name, "default")].limits, try(value.limits, {}))
    }
  ) }

  # Opt-in on-demand pool for workloads that must not be moved by spot reclamation. Tainted so ordinary
  # workloads never land here, WhenEmpty so only genuinely empty nodes are removed, and deliberately NOT
  # given the disruption windows: there is no voluntary consolidation to suppress.
  protectedNodePool = var.protected_node_pool.enabled ? {
    (var.protected_node_pool.name) = {
      weight = var.protected_node_pool.weight
      template = {
        spec = {
          nodeClassRef           = local.nodePoolDefaultNodeClassRef
          expireAfter            = "Never"
          terminationGracePeriod = var.termination_grace_period
          taints = [
            {
              key    = var.protected_node_pool.taint_key
              value  = var.protected_node_pool.taint_value
              effect = "NoSchedule"
            }
          ]
          requirements = coalesce(
            var.protected_node_pool.requirements,
            concat(
              [for item in local.nodePoolDefaultRequirements : item if item.key != "karpenter.sh/capacity-type"],
              [{ key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] }],
            )
          )
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "15m"
        budgets             = [{ nodes = "10%" }]
      }
      limits = var.protected_node_pool.limits
    }
  } : {}

  allNodePools = merge(local.nodePools, local.protectedNodePool)
}
