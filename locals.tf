locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
  cluster_autoscaler_enabled  = var.autoscaling && !var.karpenter.enabled # We disable eks cluster autoscaler in case karpenter have been enabled as karpenter replaces cluster autoscaler and there are possibility of conflicts if both are enabled

  vpc_id     = var.vpc.create.name != null ? module.vpc[0].id : var.vpc.link.id
  subnet_ids = var.vpc.create.name != null ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids

  # External Secrets. The grouped `external_secrets` object is the current interface; the
  # older top-level variables still win when explicitly set, so existing callers (and the
  # staged upgrade runbook in main.tf, which pins external_secrets_chart_version) keep working.
  external_secrets_enabled       = var.enable_external_secrets && var.external_secrets.enabled
  external_secrets_namespace     = coalesce(var.external_secrets_namespace, var.external_secrets.namespace)
  external_secrets_chart_version = coalesce(var.external_secrets_chart_version, var.external_secrets.chart.version)

  # Default configuration values; user overrides (e.g. only replicaCount) are merged on top in cluster_addons
  default_configuration_values = {
    coredns = {
      replicaCount = 2
      resources = {
        limits = {
          memory = "171Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "70Mi"
        }
      }
      corefile = <<-EOT
    .:53 {
        errors
        health {
            lameduck 5s
          }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          ttl 120
        }
        prometheus :9153
        forward . /etc/resolv.conf {
          max_concurrent 2000
        }
        cache 30
        loop
        reload
        loadbalance
    }
    EOT
    }
  }

  cluster_addons_merged = { for key, value in merge(var.cluster_addons, var.default_addons) : key => provider::deepmerge::mergo({ configuration_values = try(local.default_configuration_values[key], {}) }, value) }
  cluster_addons        = { for key, value in local.cluster_addons_merged : key => merge(value, { configuration_values = jsonencode(value.configuration_values) }) }

  meta_system_namespace = "meta-system"

  # Use priority classes exposed by priority-class submodule instead of mirroring defaults here.
  priority_class_map = try(module.priority_class.priority_class_map, {})
  highest_priority_class_value = try(
    max([for pc in values(local.priority_class_map) : tonumber(pc.value)]...),
    1000000
  )
  highest_priority_class_names = [
    for name, pc in local.priority_class_map : name
    if tonumber(pc.value) == local.highest_priority_class_value
  ]
  # Karpenter runs at system-cluster-critical (2,000,000,000), the upstream chart default. An earlier revision
  # substituted the priority-class submodule's highest class (1,000,000), which demoted karpenter below every
  # genuinely cluster-critical component and forfeited kubelet critical-pod protection -- so under node pressure
  # the component responsible for ADDING capacity became a preemption candidate. Override via
  # var.karpenter.configs.priorityClassName if a setup genuinely needs a different class.
  karpenter_priority_class_name = "system-cluster-critical"
  karpenter_default_configs = {
    replicas          = 2
    priorityClassName = local.karpenter_priority_class_name
  }
  karpenter_configs = merge(local.karpenter_default_configs, try(var.karpenter.configs, {}))

  # Reserve the managed node groups for cluster-critical components. Application workloads are then provisioned
  # by karpenter onto dedicated capacity instead of crowding onto the small system nodes, where they compete
  # with the very controller that provisions their capacity.
  #
  # Gated on karpenter being enabled: without it there is nowhere else for workloads to run, so tainting the
  # only node groups would leave the cluster unable to schedule anything at all.
  #
  # A node group that declares its own `taints` is left exactly as the operator wrote it.
  node_groups_taint_enabled = var.karpenter.enabled && var.node_groups_system_taint.enabled

  # Built through a for-expression over a conditional list rather than a ternary on the object itself.
  # A ternary would have to unify `{ system = {...} }` with `{}`, which terraform rejects as inconsistent
  # types -- and it rejects it at plan time, not at validate, so the failure would reach consumers.
  # This yields map(object({key,value,effect})) in both the enabled and disabled cases.
  node_groups_system_taint = {
    for name in(local.node_groups_taint_enabled ? ["system"] : []) : name => {
      key    = var.node_groups_system_taint.key
      value  = var.node_groups_system_taint.value
      effect = var.node_groups_system_taint.effect
    }
  }

  # A node group that declares its own taints keeps them exactly as written; the rest receive the system
  # taint, or an empty map when tainting is off.
  node_groups = {
    for name, config in var.node_groups : name => merge(config, {
      taints = try(config.taints, local.node_groups_system_taint)
    })
  }

  # Karpenter node AMI family is derived from the DECLARED managed node group ami_type rather than sampled from a
  # running instance, so the selection is a pure function of configuration and cannot change on its own.
  karpenter_node_ami_type = try(var.node_groups_default.ami_type, "AL2023_x86_64_STANDARD")
  karpenter_ami_family = (
    startswith(local.karpenter_node_ami_type, "AL2023") ? "al2023" :
    startswith(local.karpenter_node_ami_type, "BOTTLEROCKET") ? "bottlerocket" :
    startswith(local.karpenter_node_ami_type, "AL2") ? "al2" :
    "al2023"
  )
  karpenter_ami_alias = "${local.karpenter_ami_family}@latest"

  # The consumer's defaults bucket wins; the derived alias only fills the gap when they left it unset.
  # Written as a nested merge rather than a whole-object replacement so that setting any single field
  # keeps its siblings on the module defaults.
  karpenter_resource_configs_defaults = merge(
    try(var.karpenter.resource_configs_defaults, {}),
    {
      default = merge(
        try(var.karpenter.resource_configs_defaults.default, {}),
        {
          nodeClass = merge(
            { amiAlias = local.karpenter_ami_alias },
            try(var.karpenter.resource_configs_defaults.default.nodeClass, {}),
          )
        }
      )
    }
  )
}
