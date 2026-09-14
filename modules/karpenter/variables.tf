variable "cluster_name" {
  type        = string
  description = "The eks cluster name"
}

variable "cluster_version" {
  type        = string
  description = "The eks cluster version"
}

variable "oidc_provider_arn" {
  description = "EKC oidc provider arn in format 'arn:aws:iam::<account-id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc-id>'."
  type        = string
}

variable "cluster_endpoint" {
  type        = string
  description = "The eks cluster endpoint"
}

variable "subnet_ids" {
  type        = list(string)
  description = "VPC subnet ids used for default Ec2NodeClass as subnet selector."
}

variable "enable_v1_permissions" {
  description = "Determines whether to enable permissions suitable for v1+"
  type        = bool
  default     = true
}

variable "enable_pod_identity" {
  type        = bool
  default     = true
  description = "Determines whether to enable support for EKS pod identity"
}

variable "create_pod_identity_association" {
  type        = bool
  default     = true
  description = "Determines whether to create pod identity association"
}

variable "node_iam_role_additional_policies" {
  type        = any
  default     = {}
  description = "Additional policies to be added to the IAM role"
}

variable "chart_version" {
  type        = string
  default     = "1.14.1"
  description = "The app chart version"
}

variable "resource_chart_version" {
  type        = string
  default     = "0.1.2"
  description = "The dasmeta karpenter-nodes chart version"
}

variable "namespace" {
  description = "The namespace to install main helm."
  type        = string
  default     = "karpenter"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create namespace if requested"
}

variable "atomic" {
  type        = bool
  default     = false
  description = "Whether use helm deploy with --atomic flag"
}

variable "wait" {
  type        = bool
  default     = true
  description = "Whether use helm deploy with --wait flag"
}

variable "configs" {
  type        = any
  default     = {}
  description = <<-EOT
    Configurations to pass and override default ones. Check the helm chart available configs here:
    https://github.com/aws/karpenter-provider-aws/blob/v1.14.1/charts/karpenter/values.yaml

    NOTE on `replicas`: the module default is 2 and lowering it to 1 is supported but carries real risk.
    A single-replica controller has no failover during ANY restart, including a rollout, a node drain or an
    OOMKill. While it is restarting nothing consumes the interruption queue, and a backlog past the 120
    second notice means nodes are reclaimed before any drain starts. The corrected controller resources
    remove the OOMKill cause, but a single replica still leaves the restart window uncovered. Use 1 only where the cluster genuinely cannot host 2 (a single node, or a single
    availability zone), and prefer fixing the cluster shape instead.
  EOT
}

variable "resource_configs" {
  type = object({
    ec2NodeClasses = optional(any, {}) # This is for additional node classes configuration, by default it creates ec2NodeClass resource named 'default' and this attaches to all nodepools based on var.resource_configs_defaults configs
    nodePools      = optional(any, {}) # The nodepool resources definition, it uses some predefined/default values from var.resource_configs_defaults which can be customized, check helm chart or/and karpenter docs for schema/fields
  })
  default     = {}
  description = "Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes"
}

variable "resource_configs_defaults" {
  type = object({
    default = optional(object({
      nodeClass = optional(object({
        amiAlias = optional(string, null) # null means "derive from the managed node group ami_type at the root module"
        # Declarative AMI selection in `family@version` form. `@latest` means node replacement is CONTINUOUS
        # AND UNATTENDED: karpenter re-checks AMI data about every minute and starts a paced roll when AWS
        # publishes a new image, with no terraform run involved. That is how nodes receive OS and kernel
        # patches unattended, and it is safe because drift is voluntary disruption so budgets and windows
        # apply. Pin a version (e.g. "al2023@v20240807") to stop drift, at the cost of no patching until the
        # pin moves.
        amiSelectorTerms   = optional(any, null)    # full override of AMI selection; when set, amiAlias is ignored
        amiFamily          = optional(string, null) # only needed when amiSelectorTerms is used without an alias
        detailedMonitoring = optional(bool, true)   # 1-minute EC2 metrics rather than 5-minute
        metadataOptions = optional(any, {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2 # blocks IMDS access from containers not on the host network
          httpTokens              = "required"
        })
        blockDeviceMappings = optional(any, [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize = "100Gi"
              volumeType = "gp3"
              encrypted  = true
            }
          }
        ])
      }), {})

      nodeClassRef = optional(object({
        group = optional(string, "karpenter.k8s.aws") # CRD group of the node class
        kind  = optional(string, "EC2NodeClass")      # CRD kind of the node class
        name  = optional(string, "default")           # which node class pools of this type reference
      }), {})

      requirements = optional(any, [ # free-form: passed straight to the NodePool CRD, so not typed
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "Lt"
          values   = ["33"] # <=32 core cpu nodes, widened to deepen the spot candidate pool
        },
        {
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Lt"
          values   = ["131073"] # <=128 Gb memory nodes, widened to deepen the spot candidate pool
        },
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "Gt"
          values   = ["1"] # >1 core, k8s struggles on single-core nodes
        },
        {
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Gt"
          values   = ["2000"] # >2Gb, k8s struggles to start smaller ones
        },
        {
          # Exclude the burstable "t" family. Two independent reasons, both seen in this fleet:
          #  1. t instances are CPU-credit based, so under sustained load they throttle to a fraction of
          #     their advertised vCPU, surfacing as latency that looks like an application fault.
          #  2. they sit in the most contended spot pools and are reclaimed noticeably more often.
          # Karpenter picks the CHEAPEST instance satisfying the constraints, and without this a t3.2xlarge
          # very often was that instance -- which is how a cheap default becomes an availability problem.
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["c", "m", "r"] # compute (1:2), general purpose (1:4), memory optimised (1:8)
        },
        {
          key      = "karpenter.k8s.aws/instance-generation"
          operator = "Gt"
          values   = ["4"] # gen 5+: better price/performance and more distinct spot pools to fall back on
        },
        {
          # Exclude the "flex" variants. They are compute/general instances by category, so the filter above
          # admits them, and karpenter picks the cheapest match -- c7i-flex and c8i-flex were both selected
          # on a test cluster. They deliver a ~40% CPU baseline with burst above it, which is the same
          # sustained-load throttling profile the "t" family is excluded for, arriving through a family name
          # the category filter does not catch.
          #
          # This is a NAME list because karpenter has no label for the behaviour, so a new flex family is
          # admitted until it is added here. Names that do not exist are harmless -- they simply never match.
          key      = "karpenter.k8s.aws/instance-family"
          operator = "NotIn"
          values   = ["c7i-flex", "m7i-flex", "r7i-flex", "c8i-flex", "m8i-flex", "r8i-flex"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"] # amd64 linux is the platform arch in use
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"] # spot first, on-demand when no spot is available
        }
      ])

      # Upper bound on node drain before remaining pods are force-removed. UNSET on purpose: setting it makes
      # a node hosting blocking PodDisruptionBudgets or karpenter.sh/do-not-disrupt pods ELIGIBLE for drift,
      # and force-deletes those pods when it elapses -- turning both protections into a delay rather than a
      # guarantee. Leave unset so a workload marked always-up stays up; its node keeps an older AMI until a
      # human moves it, which assessment section D4 surfaces.
      terminationGracePeriod = optional(string, null)

      # How long a node may live before being replaced on age. Left as "Never" deliberately: expiry is NOT
      # gated by disruption budgets, so a finite value replaces nodes unpaced and outside any window. AMI
      # drift, which IS budget-paced, handles patching instead.
      expireAfter = optional(string, "Never")

      disruption = optional(object({
        consolidationPolicy = optional(string, "Balanced") # weighs cost saving against disruption instead of consolidating whenever anything cheaper exists
        consolidateAfter    = optional(string, "15m")      # how long a node must be a candidate before it is acted on
        # Voluntary disruption budgets, passed straight to the CRD. Entries carrying `schedule` and
        # `duration` are protection windows: `nodes = "0"` blocks the listed reasons while the window is
        # open. IMPORTANT -- karpenter evaluates schedules in UTC ONLY and has no timezone support, so the
        # default below suits central Europe and should be re-cut for other regions. Multiple budgets
        # resolve most-restrictive-wins. These gate VOLUNTARY disruption only: they never delay spot
        # interruption handling, and never delay node expiry.
        budgets = optional(any, [
          { nodes = "10%" }, # never disrupt more than a tenth of the pool at once
          {
            nodes    = "0"                          # block the reasons below entirely while the window is open
            schedule = "0 6 * * mon-fri"            # opens 06:00 UTC on weekdays (about 08:00 in central Europe)
            duration = "12h"                        # through 18:00 UTC
            reasons  = ["Drifted", "Underutilized"] # "Empty" stays allowed: removing an empty node disrupts nothing
          },
        ])
      }), {})

      limits = optional(any, { cpu = 1000 }) # ceiling on total capacity this pool may provision
    }), {})

    # Preset for ON-DEMAND capacity that ordinary workloads must not land on: monitoring, singletons,
    # stateful services, anything that cannot survive its node disappearing. A pool referencing
    # `nodeClassRef.name = "on-demand"` inherits all of the below, so declaring one is three lines rather
    # than fifty. Every field stays individually overridable on the pool.
    on-demand = optional(object({
      nodeClass = optional(object({
        amiAlias           = optional(string, null) # null means "derive from the managed node group ami_type at the root module"
        amiSelectorTerms   = optional(any, null)    # full override of AMI selection; when set, amiAlias is ignored
        amiFamily          = optional(string, null) # only needed when amiSelectorTerms is used without an alias
        detailedMonitoring = optional(bool, true)   # 1-minute EC2 metrics rather than 5-minute
        metadataOptions = optional(any, {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2 # blocks IMDS access from containers not on the host network
          httpTokens              = "required"
        })
        blockDeviceMappings = optional(any, [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize = "100Gi"
              volumeType = "gp3"
              encrypted  = true
            }
          }
        ])
      }), {})

      nodeClassRef = optional(object({
        group = optional(string, "karpenter.k8s.aws")
        kind  = optional(string, "EC2NodeClass")
        name  = optional(string, "on-demand")
      }), {})

      # Orders pools when several could take the same pod; highest wins, and an unset weight counts as 0.
      # Must exceed the general pool's weight, which is why this is not left to chance.
      weight = optional(number, 50)

      # Applied to the pool so ordinary workloads never land on capacity you are paying on-demand rates for.
      # A workload opts in by tolerating this AND selecting on-demand -- the toleration alone only makes the
      # nodes eligible, it does not keep the pod off spot.
      #
      # `dedicated=<node class>` is the convention kubernetes itself uses for reserved nodes, so it reads
      # the same way in any cluster and needs no vendor prefix to explain. The value tracks the node class
      # name, so a second preset added later follows the same shape without inventing a new key.
      #
      # A pool that declares its own `taints` REPLACES this list rather than adding to it -- taints are not
      # merged entry by entry, because a half-inherited taint set is worse than either choice made cleanly.
      # Re-state this entry alongside your own if you want both.
      taints = optional(any, [
        {
          key    = "dedicated"
          value  = "on-demand"
          effect = "NoSchedule"
        }
      ])

      requirements = optional(any, [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["on-demand"] # not subject to reclamation, which is the whole point of this pool
        },
        {
          # Read this as what it EXCLUDES, not what it includes: the specialised families -- gpu (g, p),
          # storage optimised (i, d, h), high memory (x, z), inference and training (inf, trn). None of them
          # is ever the right answer for a singleton, and all of them are an expensive surprise if one
          # happens to be the cheapest shape that fits in some region. On-demand does not need instance
          # diversity the way spot does, so there is nothing to gain from a wider set.
          #
          # Burstable IS included here and excluded from the general pool, for the same reason the system
          # node group uses it: this capacity carries small, steady workloads, which is the profile
          # burstable suits. The general pool excludes "t" because bulk workloads drive sustained CPU and
          # burstable throttles under it; that does not apply to a handful of singletons. Narrow to
          # ["c", "m", "r"] if something CPU-hungry lands here, such as a metrics store under real load.
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["t", "c", "m", "r"]
        },
        {
          # >2 rather than the general pool's >4, which would exclude the t family outright: t3 is
          # generation 3, and t4g is arm64 and already excluded by the architecture requirement.
          key      = "karpenter.k8s.aws/instance-generation"
          operator = "Gt"
          values   = ["2"]
        },
        {
          # Above the general pool's 2000MiB, because admitting the t family makes 2GiB shapes reachable and
          # karpenter picks the cheapest that fits -- observed selecting a t3a.small. That is the size ruled
          # out for the system node group for the same two reasons: the VPC CNI allows only 11 pods on it
          # ((3 ENIs x (4 IPs - 1)) + 2) and the DaemonSets take about 5 of those, and ~1.5GiB allocatable is
          # thin for anything worth protecting. 3000 admits t3.medium at 4GiB, the smallest shape that behaves.
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Gt"
          values   = ["3000"]
        },
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "Lt"
          values   = ["33"]
        },
        {
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Lt"
          values   = ["131073"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        }
      ])

      terminationGracePeriod = optional(string, null)
      expireAfter            = optional(string, "Never")

      disruption = optional(object({
        # WhenEmpty, not Balanced: this pool should only ever lose a genuinely empty node. Consolidating a
        # node that still holds a protected workload is the disruption the pool exists to avoid.
        consolidationPolicy = optional(string, "WhenEmpty")
        consolidateAfter    = optional(string, "15m")
        # No protection window here on purpose. With WhenEmpty the only voluntary disruption is removing an
        # empty node, which disrupts nothing and is therefore safe at any hour.
        budgets = optional(any, [{ nodes = "10%" }])
      }), {})

      # Same ceiling as the other presets. A limit is a runaway guard, not a cost budget: when it binds,
      # karpenter stops provisioning and the pods waiting on capacity simply pend -- and the pods waiting on
      # THIS pool are the ones that were moved here because they must stay up. A low ceiling turns a cost
      # control into an availability incident. Control spend by what you put here, not by capping the pool.
      limits = optional(any, { cpu = 1000 })
    }), {})

    gpu = optional(object({
      nodeClass = optional(object({
        amiAlias = optional(string, "al2023@latest") # GPU node classes track the AL2023 GPU image
        # Declarative AMI selection in `family@version` form. `@latest` means node replacement is CONTINUOUS
        # AND UNATTENDED: karpenter re-checks AMI data about every minute and starts a paced roll when AWS
        # publishes a new image, with no terraform run involved. That is how nodes receive OS and kernel
        # patches unattended, and it is safe because drift is voluntary disruption so budgets and windows
        # apply. Pin a version (e.g. "al2023@v20240807") to stop drift, at the cost of no patching until the
        # pin moves.
        amiSelectorTerms   = optional(any, null)    # full override of AMI selection; when set, amiAlias is ignored
        amiFamily          = optional(string, null) # only needed when amiSelectorTerms is used without an alias
        detailedMonitoring = optional(bool, true)   # 1-minute EC2 metrics rather than 5-minute
        metadataOptions = optional(any, {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2 # blocks IMDS access from containers not on the host network
          httpTokens              = "required"
        })
        blockDeviceMappings = optional(any, [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize = "100Gi"
              volumeType = "gp3"
              encrypted  = true
            }
          }
        ])
      }), {})

      nodeClassRef = optional(object({
        group = optional(string, "karpenter.k8s.aws") # CRD group of the node class
        kind  = optional(string, "EC2NodeClass")      # CRD kind of the node class
        name  = optional(string, "gpu")               # which node class pools of this type reference
      }), {})

      requirements = optional(any, [ # free-form: passed straight to the NodePool CRD, so not typed
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"]
        }
      ])

      # Upper bound on node drain before remaining pods are force-removed. UNSET on purpose: setting it makes
      # a node hosting blocking PodDisruptionBudgets or karpenter.sh/do-not-disrupt pods ELIGIBLE for drift,
      # and force-deletes those pods when it elapses -- turning both protections into a delay rather than a
      # guarantee. Leave unset so a workload marked always-up stays up; its node keeps an older AMI until a
      # human moves it, which assessment section D4 surfaces.
      terminationGracePeriod = optional(string, null)

      # How long a node may live before being replaced on age. Left as "Never" deliberately: expiry is NOT
      # gated by disruption budgets, so a finite value replaces nodes unpaced and outside any window. AMI
      # drift, which IS budget-paced, handles patching instead.
      expireAfter = optional(string, "Never")

      disruption = optional(object({
        consolidationPolicy = optional(string, "WhenEmpty") # weighs cost saving against disruption instead of consolidating whenever anything cheaper exists
        # Short on purpose. GPU instances are the most expensive capacity in the cluster, so an idle one is
        # the costliest thing to keep, and with WhenEmpty above there is no disruption risk either way --
        # an empty node has nothing to disrupt. This is purely a cost-versus-latency trade.
        #
        # The cost of a longer value is silent and continuous; the cost of this short one is visible -- if
        # jobs queue up behind node provisioning (boot, driver init and a container image that is often tens
        # of gigabytes), someone notices and raises it. Prefer the failure you can see. Raise it for bursty
        # inference or interactive workloads with short gaps between jobs; leave it for batch training,
        # where gaps are long and the node would sit idle anyway.
        consolidateAfter = optional(string, "1m")
        # Voluntary disruption budgets, passed straight to the CRD. Entries carrying `schedule` and
        # `duration` are protection windows: `nodes = "0"` blocks the listed reasons while the window is
        # open. IMPORTANT -- karpenter evaluates schedules in UTC ONLY and has no timezone support, so the
        # default below suits central Europe and should be re-cut for other regions. Multiple budgets
        # resolve most-restrictive-wins. These gate VOLUNTARY disruption only: they never delay spot
        # interruption handling, and never delay node expiry.
        budgets = optional(any, [{ nodes = "10%" }])
      }), {})

      limits = optional(any, { cpu = 1000 }) # ceiling on total capacity this pool may provision
    }), {})
  })
  default     = {}
  description = <<-EOT
    Defaults applied to every karpenter node pool and node class, in three presets: `default` for ordinary
    workloads, `gpu` for GPU node classes, and `on-demand` for capacity that ordinary workloads must not
    land on. A pool inherits a preset by referencing that node class in `nodeClassRef.name`, so declaring
    on-demand capacity is a nodeClassRef and nothing else.

    Every field is individually optional, so setting one leaves its siblings on their defaults -- overriding
    `disruption.consolidateAfter` keeps `consolidationPolicy` and the protection window rather than dropping
    them.

    NOTE: only the keys `default`, `gpu` and `on-demand` are accepted here. Terraform silently drops object attributes a
    type does not declare, so anything placed at the top level never takes effect. The root module validates
    against that; see the corresponding validation on var.karpenter.
  EOT
}

variable "tags" {
  description = "Extra tags to attach to eks cluster."
  type        = any
  default     = {}
}

variable "controller_resources" {
  type = object({
    requests = optional(object({
      cpu    = optional(string, "250m")  # cpu request for the karpenter controller, value validated in production
      memory = optional(string, "512Mi") # memory request for the karpenter controller, value validated in production
    }), {})
    limits = optional(object({
      cpu    = optional(string, null)  # cpu limit, intentionally unset by default: a cap throttles the controller during the very scale/interruption events it must react to
      memory = optional(string, "1Gi") # memory limit, bounds node-level risk from unbounded growth
    }), {})
  })
  default     = {}
  description = <<-EOT
    Resources for the karpenter controller container.
    Defaults are the values validated in production after controller OOMKills and cpu throttling were observed
    with the previous hard-coded 200m/256Mi limits. The cpu limit is deliberately left unset: throttling this
    controller during a scale-up or spot-interruption storm is the failure being prevented, so the scheduler
    should arbitrate via the request instead. Raise `limits.memory` on large clusters, where controller memory
    scales with node, pod and instance-type-offering counts.
  EOT
}

