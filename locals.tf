locals {
  account_id = coalesce(var.account_id, try(data.aws_caller_identity.current[0].account_id, null))
  region     = coalesce(var.region, try(data.aws_region.current[0].name, null))

  eks_oidc_root_ca_thumbprint = replace(try(module.eks-cluster[0].oidc_provider_arn, ""), "/.*id//", "")
  cluster_autoscaler_enabled  = var.autoscaling && !var.karpenter.enabled # We disable eks cluster autoscaler in case karpenter have been enabled as karpenter replaces cluster autoscaler and there are possibility of conflicts if both are enabled

  vpc_id     = var.vpc.create.name != null ? module.vpc[0].id : var.vpc.link.id
  subnet_ids = var.vpc.create.name != null ? module.vpc[0].private_subnets : var.vpc.link.private_subnet_ids

  # Default coredns configuration_values; user overrides (e.g. only replicaCount) are merged on top in cluster_addons
  default_coredns_configuration_values = {
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

  cluster_addons = { for key, value in merge(var.cluster_addons, var.default_addons) : key => merge(
    value,
    key == "coredns" ? { configuration_values = jsonencode(merge(local.default_coredns_configuration_values, try(value.configuration_values, null) != null ? value.configuration_values : {})) } : (
      try(value.configuration_values, null) == null ? {} : { for k, v in(can(tostring(value.configuration_values)) ? { configuration_values = null } : { configuration_values = jsonencode(value.configuration_values) }) : k => v if v != null }
    )
  ) }

  meta_system_namespace = "meta-system"
}
