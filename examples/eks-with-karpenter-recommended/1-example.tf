# Recommended Karpenter setup.
#
# This example is the reference for a stable spot-backed cluster. Options the module already applies by
# default are written out but COMMENTED, so you can see the full picture in one place without re-declaring
# behaviour you already get. Anything left UNCOMMENTED is set on purpose and says why on the line above it.
#
# Rule of thumb when copying this: start by deleting every commented block. If the result still expresses
# what you need, you are done -- the defaults are the recommendation.

module "this" {
  source = "../.."

  cluster_name = local.cluster_name

  # The subnets must span at least 2 availability zones, otherwise the system node group cannot place its 2
  # nodes in 2 zones and karpenter's second replica can never schedule. The module fails the plan when 2+
  # karpenter replicas are requested with fewer than 2 subnets, but it cannot see how those subnets map to
  # zones, so confirm the spread yourself.
  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  # The system node group hosts karpenter itself plus the other cluster-critical addons.
  #
  # Set explicitly, and this is the single most important sizing decision here: karpenter's own chart requires
  # each of its 2 replicas to sit on a SEPARATE node in a SEPARATE availability zone. Three chart defaults
  # combine to force it -- required hostname podAntiAffinity, a DoNotSchedule zone topologySpread, and a
  # nodeAffinity of `karpenter.sh/nodepool DoesNotExist`.
  #
  # That last one is the trap: KARPENTER-MANAGED NODES DO NOT COUNT. Only nodes from a managed node group are
  # eligible to host the controller. A production cluster was observed running 8 nodes across 3 availability
  # zones and still could not schedule a second replica, because 7 of them were karpenter-provisioned and only
  # 1 was from a managed node group. `kubectl get nodes` looked comfortably highly available; the controller
  # was not. So size THIS node group for 2 in 2 zones -- total cluster node count is irrelevant.
  #
  # The cost of getting it wrong is not theoretical. A single-replica controller has no failover during any
  # restart, rollout or drain, and in one production incident that gap meant spot interruption messages went
  # unconsumed for 179 seconds -- past the 120 second notice -- so nodes were reclaimed before any drain began.
  #
  # Verify after apply (expect 2+ rows in 2+ distinct zones):
  #   kubectl get nodes -L topology.kubernetes.io/zone,karpenter.sh/nodepool | grep -v 'karpenter.sh/nodepool'
  node_groups = {
    system = {
      min_size     = 2
      desired_size = 2
      max_size     = 3
      # taints = {                              # DEFAULT when karpenter is enabled, and RECOMMENDED.
      #   system = {                            # Reserves this group for cluster-critical components so
      #     key    = "CriticalAddonsOnly"        # application pods do not compete with the karpenter
      #     value  = "true"                      # controller on two small nodes. Karpenter, the coredns
      #     effect = "NO_SCHEDULE"               # addon and the EBS CSI controller all tolerate this key.
      #   }                                      # Disable with node_groups_system_taint.enabled = false,
      # }                                        # which suits dev/test clusters.
    }
  }

  # node_groups_default = {
  #   instance_types = ["t3.medium", "t3a.medium"]            # DEFAULT and RECOMMENDED up to ~50 cluster nodes.
  #   capacity_type  = "ON_DEMAND"                            # DEFAULT
  #   ami_type       = "AL2023_x86_64_STANDARD"               # DEFAULT. Also determines the karpenter AMI alias family.
  #   disk_size      = 50                                     # DEFAULT
  # }
  #
  # Burstable is the right choice HERE, unlike for application nodes: system node load is low and steady
  # (one karpenter replica, one coredns, a CSI controller, the DaemonSets), which is exactly the profile
  # burstable instances suit. t3.medium sustains 400m and the system pods take ~250m plus roughly 3m per
  # cluster node of karpenter, so it holds to about 50 nodes. Past that use ["c6a.large", "c6i.large"].
  #
  # t3.small does NOT work at any size: 11 pods max via the VPC CNI, of which DaemonSets take ~5, and 2 GiB
  # cannot hold the karpenter memory limit plus coredns and the CSI controller.

  karpenter = {
    enabled = true

    # configs = {
    #   replicas          = 2                         # DEFAULT and RECOMMENDED, and the reason the system node
    #                                                 # group above is sized 2-across-2-zones. Do not lower to 1
    #                                                 # in production: a single replica has no failover during any
    #                                                 # controller restart, rollout or node drain. If a cluster
    #                                                 # cannot host 2, fix the node group rather than dropping to 1.
    #   priorityClassName = "system-cluster-critical" # DEFAULT and RECOMMENDED. Keeps karpenter from being
    #                                                 # preempted ahead of other cluster-critical components.
    # }

    # controller_resources = {                        # DEFAULT and RECOMMENDED.
    #   requests = { cpu = "250m", memory = "512Mi" }
    #   limits   = { memory = "1Gi" }                 # NOTE there is deliberately NO cpu limit: throttling the
    #                                                 # controller during a scale-up or spot-interruption storm
    #                                                 # is the exact failure being prevented.
    # }
    #
    # Raise `limits.memory` on large clusters -- controller memory scales with node, pod and instance-type
    # counts. If you measured different values for your cluster, set them here rather than relying on a live
    # hotfix: an in-cluster patch is silently reverted by the next terraform apply.

    # resource_configs_defaults = {              # ALL of the following are DEFAULTS and RECOMMENDED.
    #   default = {                                # Every field is individually optional, so setting one
    #     nodeClass = {                            # leaves its siblings on the module defaults.
    #       amiAlias = "al2023@latest"             # derived from node_groups_default.ami_type when unset.
    #     }                                        # `@latest` means node replacement is CONTINUOUS AND
    #                                              # UNATTENDED: karpenter re-checks about every minute and
    #                                              # rolls nodes when AWS publishes a new AMI, with no
    #                                              # terraform run involved. That is how nodes get OS and
    #                                              # kernel patches; it is paced by the budgets below.
    #                                              # Pin a version to stop drift, at the cost of no patching.
    #
    #     terminationGracePeriod = null            # DEFAULT, and leaving it unset is the recommendation.
    #                                              # Setting it makes nodes hosting blocking PDBs or
    #                                              # do-not-disrupt pods ELIGIBLE for drift and force-deletes
    #                                              # those pods, turning both protections into a delay.
    #
    #     expireAfter = "Never"                    # DEFAULT. Expiry is NOT gated by disruption budgets, so a
    #                                              # finite value replaces nodes unpaced and outside any
    #                                              # window. AMI drift handles patching instead, and it IS paced.
    #
    #     disruption = {
    #       consolidationPolicy = "Balanced"       # weighs saving against disruption
    #       consolidateAfter    = "15m"            # a brief dip no longer triggers removal
    #       budgets = [
    #         { nodes = "10%" },                   # never move more than a tenth of the pool at once
    #         {                                    # the protection window, as an ordinary budget entry
    #           nodes    = "0"
    #           schedule = "0 6 * * mon-fri"       # 06:00 UTC weekdays
    #           duration = "12h"                   # through 18:00 UTC
    #           reasons  = ["Drifted", "Underutilized"] # "Empty" stays allowed
    #         },
    #       ]
    #     }
    #
    #     requirements = [ ... ]                   # DEFAULT: linux amd64, cpu 2-32, memory 2-128Gi,
    #                                              # generation > 4, categories c/m/r, spot and on-demand.
    #                                              # Wide on purpose: instance flexibility is what lowers
    #                                              # spot interruption frequency.
    #     limits = { cpu = 1000 }                  # DEFAULT ceiling on provisioned capacity.
    #   }
    # }
    #
    # IMPORTANT: karpenter evaluates budget schedules in UTC ONLY -- it has no timezone support -- so the
    # default window suits central Europe and is wrong elsewhere. See docs/eks-stability-guide.md section 2.1
    # for a per-region table. A recorded incident evicted replicas at 19:17 UTC, just outside this window.

    resource_configs = {
      nodePools = {
        # The general spot-first pool. Everything without a specific placement requirement lands here.
        general = { weight = 1 }

        # Protected on-demand capacity, built with standard node pool config -- there is no special input
        # for this, and none is needed. Turn it on for any cluster running an ingress controller,
        # monitoring, or single-replica/stateful services: those are the workloads that repeatedly turned a
        # routine spot reclaim into an outage. Delete this pool if you do not want the on-demand cost.
        #
        # Note it declares its own `budgets`. A pool that does so owns them completely, so the module's
        # disruption windows are NOT appended -- which is what this pool wants: it should only ever lose a
        # genuinely empty node, at any hour.
        protected = {
          # Orders pools when several could take the same pod; highest wins. Must exceed `general` above,
          # since an unset weight counts as 0. Value is arbitrary (1-100). Guide 2.4 explains why this is
          # needed even when the pod also selects on-demand.
          weight = 50
          template = {
            metadata = {
              labels = {
                nodetype = "protected"
              }
            }
            spec = {
              # Declare only what differs. Requirements merge by KEY, so this narrows the default
              # ["spot", "on-demand"] to on-demand and inherits everything else. Re-stating a default
              # pins the pool to today's value and stops it following the module. Guide 2.4.
              requirements = [
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["on-demand"] # not subject to reclamation, which is the whole point
                },
              ]
              # Workloads opt in by tolerating this taint AND selecting on-demand -- see http-echo-critical.yaml.
              taints = [
                {
                  key    = "dasmeta.io/protected"
                  value  = "true"
                  effect = "NoSchedule"
                }
              ]
            }
          }
          disruption = {
            consolidationPolicy = "WhenEmpty" # only ever remove a genuinely empty node
            consolidateAfter    = "15m"
            budgets             = [{ nodes = "10%" }]
          }
          limits = { cpu = 20 }
        }
      }
    }

    # resource_configs_defaults = {
    #   default = {                           # NOTE: must be nested under `default`. A top-level key here fails at plan time.
    #     requirements = [ ... ]              # DEFAULT: linux amd64, cpu 2-32, memory 2-128Gi, generation > 2,
    #                                         # both spot and on-demand. Wide on purpose: instance-type
    #                                         # flexibility is what lowers spot interruption frequency.
    #     disruption = {
    #       consolidationPolicy = "Balanced"  # DEFAULT and RECOMMENDED. Weighs cost saving against disruption
    #                                         # instead of consolidating whenever anything cheaper exists.
    #       consolidateAfter    = "15m"       # DEFAULT. A brief utilisation dip no longer triggers node removal.
    #       budgets             = [{ nodes = "10%" }] # DEFAULT, including the protection window entry.
    #     }
    #     limits = { cpu = 1000 }             # DEFAULT ceiling on total provisioned capacity.
    #   }
    # }

  }

  # Keep the rest of the example small; these are not part of the karpenter recommendation.
  alarms = {
    enabled   = false
    sns_topic = ""
  }
  enable_ebs_driver            = false
  enable_external_secrets      = false
  create_cert_manager          = false
  enable_node_problem_detector = false
  metrics_exporter             = "disabled"
  fluent_bit_configs = {
    enabled = false
  }

  nginx_ingress_controller_config = {
    enabled          = true
    name             = "nginx"
    create_namespace = true
    namespace        = "ingress-nginx"
    # Set explicitly: the ingress controller is exactly the workload that must not lose all replicas to a single
    # node disruption. 2 replicas is the minimum that lets a PodDisruptionBudget protect anything at all.
    replicacount    = 2
    metrics_enabled = true
  }
}

# A normal application: spot-backed, protected by the base chart's disruption defaults.
resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.4.0" # NOTE: 0.4.0+ is required -- it is the release that creates PodDisruptionBudgets by default
  wait       = false

  values = [file("${path.module}/http-echo.yaml")]

  depends_on = [module.this]
}

# A workload that must not be moved by spot reclamation, pinned to the protected on-demand pool.
resource "helm_release" "http_echo_critical" {
  name       = "http-echo-critical"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.4.0"
  wait       = false

  values = [file("${path.module}/http-echo-critical.yaml")]

  depends_on = [module.this]
}
