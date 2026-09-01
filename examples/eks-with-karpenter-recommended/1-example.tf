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
      taints = {
        # Keeps the system node group for cluster-critical workloads only. Karpenter tolerates this by default.
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }

  # Set explicitly: t3.small (2 vCPU / 2 GiB) is too tight once karpenter x2, coredns x2, the ALB controller,
  # external-dns and linkerd are all resident -- pods start pending for plain resource starvation, which then
  # looks like a karpenter problem. t3.medium is the smallest size that behaves.
  node_groups_default = {
    instance_types = ["t3.medium"]
    # ami_type = "AL2023_x86_64_STANDARD" # DEFAULT. Also determines the karpenter node AMI alias family.
  }

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

    # ami_alias = "al2023@latest"                     # DEFAULT (family derived from node_groups_default.ami_type).
    #                                                 # Pin to e.g. "al2023@v20240807" to stop AMI drift entirely,
    #                                                 # at the cost of nodes not receiving AMI patches until you
    #                                                 # move the pin. With @latest, a new AMI release drifts nodes,
    #                                                 # paced by the disruption budget and suppressed during the
    #                                                 # window below.

    # disruption_windows = [                          # DEFAULT and RECOMMENDED for central European traffic.
    #   {
    #     schedule = "0 6 * * mon-fri"                # 06:00 UTC weekdays
    #     duration = "12h"                            # through 18:00 UTC (20:00 CEST)
    #     reasons  = ["Drifted", "Underutilized"]     # "Empty" stays allowed: removing an empty node disrupts nothing
    #     nodes    = "0"
    #   }
    # ]
    #
    # IMPORTANT: karpenter evaluates these schedules in UTC ONLY -- it has no timezone support. The default is
    # therefore off by an hour across European daylight saving and wrong outright for other regions. A recorded
    # incident saw voluntary eviction at 19:17 UTC (21:17 CEST), just outside this window, so extend `duration`
    # if your traffic runs later. These budgets gate VOLUNTARY disruption only; they never delay spot
    # interruption handling, and never delay node expiry.

    # termination_grace_period = "24h"                # DEFAULT and RECOMMENDED. Bounds how long a node may drain
    #                                                 # before remaining pods are removed, so one pod that refuses
    #                                                 # to terminate cannot wedge a node forever. Deliberately long:
    #                                                 # once it expires karpenter removes pods REGARDLESS of their
    #                                                 # PodDisruptionBudgets, so a short value causes disruption.

    # Set explicitly: protected on-demand capacity is OFF by default because it costs real money. Turn it on for
    # any cluster running ingress controllers, monitoring, or single-replica/stateful services -- those are the
    # workloads that repeatedly turned a routine spot reclaim into an outage. See http-echo-critical.yaml for how
    # a workload opts in.
    protected_node_pool = {
      enabled = true
      limits  = { cpu = 20 }
      # name        = "protected"             # DEFAULT
      # weight      = 10                      # DEFAULT
      # taint_key   = "dasmeta.io/protected"  # DEFAULT
      # taint_value = "true"                  # DEFAULT
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
    #       budgets             = [{ nodes = "10%" }] # DEFAULT, plus the disruption_windows entries above.
    #     }
    #     limits = { cpu = 1000 }             # DEFAULT ceiling on total provisioned capacity.
    #   }
    # }

    resource_configs = {
      nodePools = {
        # The general spot-first pool. Everything without a specific placement requirement lands here.
        general = { weight = 1 }
      }
    }
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
