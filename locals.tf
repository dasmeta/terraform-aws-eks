locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
  cluster_autoscaler_enabled  = var.autoscaling && !var.karpenter.enabled # We disable eks cluster autoscaler in case karpenter have been enabled as karpenter replaces cluster autoscaler and there are possibility of conflicts if both are enabled

  vpc_id     = var.vpc.create.name != null ? module.vpc[0].id : var.vpc.link.id
  subnet_ids = var.vpc.create.name != null ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids

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
  karpenter_priority_class_name = try(local.highest_priority_class_names[0], "high")
  karpenter_default_configs = {
    replicas          = 2
    priorityClassName = local.karpenter_priority_class_name
  }
  karpenter_configs = merge(local.karpenter_default_configs, try(var.karpenter.configs, {}))
}
