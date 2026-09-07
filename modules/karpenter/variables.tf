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
    OOMKill. Field evidence: a production cluster running a single replica with the old 200m/256Mi limits had
    the controller OOMKilling every ~6 minutes, so spot interruption messages sat unread in the queue for 179
    seconds -- past the 120 second interruption notice -- and nodes were reclaimed before any drain started.
    The corrected controller resources remove that OOM cause, but a single replica still means no cover for
    the restart window. Use 1 only where the cluster genuinely cannot host 2 (a single node, or a single
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
      nodeClass = optional(any, {
        amiFamily          = null # if not specified the value will be identified based on eks managed nodes ami id, the valid values are for example "AL2", "AL2023"
        detailedMonitoring = true
        metadataOptions = {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2 # This is changed to disable IMDS access from containers not on the host network
          httpTokens              = "required"
        }
        blockDeviceMappings = [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize = "100Gi"
              volumeType = "gp3"
              encrypted  = true
            }
          }
        ]
      })
      nodeClassRef = optional(any, {
        group = "karpenter.k8s.aws"
        kind  = "EC2NodeClass"
        name  = "default"
      }),
      requirements = optional(any, [
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "Lt"
          values   = ["33"] # <=32 core cpu nodes, widened from 9 to deepen the spot candidate pool and lower interruption rate
        },
        {
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Lt"
          values   = ["131073"] # <=128 Gb memory nodes, widened from 33000 to deepen the spot candidate pool
        },
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "Gt"
          values   = ["1"] # > core cpu nodes
        },
        {
          key      = "karpenter.k8s.aws/instance-memory"
          operator = "Gt"
          values   = ["2000"] #  >2Gb Gb memory nodes as k8s struggles to start small ones
        },
        {
          # Exclude the burstable "t" family. Two independent reasons, both seen in this fleet:
          #  1. t instances are CPU-credit based. Under sustained load they throttle to a fraction of their
          #     advertised vCPU, which surfaces as latency and timeouts that look like application faults.
          #  2. they sit in the most contended spot pools, so they are reclaimed noticeably more often.
          # Karpenter picks the cheapest instance that satisfies the constraints, and without this a
          # t3.2xlarge is very often that instance -- which is how a "cheap" default becomes an availability
          # problem. Override this requirement to pin specific families when a workload genuinely wants them.
          key      = "karpenter.k8s.aws/instance-category"
          operator = "In"
          values   = ["c", "m", "r"] # compute (1:2), general purpose (1:4), memory optimised (1:8)
        },
        {
          key      = "karpenter.k8s.aws/instance-generation"
          operator = "Gt"
          values   = ["4"] # gen 5+ only: better price/performance, and more distinct spot pools to fall back on
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"] # amd64 linux is main platform arch we will use
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"] # both spot and on-demand nodes, it will look at first available spot and if no then on-demand
        }
      ])
      disruption = optional(any, {
        consolidationPolicy = "Balanced" # weighs cost saving against disruption instead of consolidating whenever anything cheaper exists
        consolidateAfter    = "15m"      # raised from 3m: a brief utilization dip used to be enough to trigger node removal
        budgets = [
          { nodes : "10%" } # allows karpenter to only deprovision/disrupt/recreate 10% of nodes at a time for consolidation/cost-optimization, to have more stable workloads
        ]
      }),
      limits = optional(any, {
        cpu = 1000
      })
    }), {})
    gpu = optional(object({
      nodeClass = optional(any, {
        amiFamily          = null # if not specified the value will be identified based on eks managed nodes ami id, the valid values are for example "AL2", "AL2023"
        ami_name           = "amazon-eks-gpu-node-1.32-v20251120"
        detailedMonitoring = true
        metadataOptions = {
          httpEndpoint            = "enabled"
          httpProtocolIPv6        = "disabled"
          httpPutResponseHopLimit = 2 # This is changed to disable IMDS access from containers not on the host network
          httpTokens              = "required"
        }
        blockDeviceMappings = [
          {
            deviceName = "/dev/xvda"
            ebs = {
              volumeSize = "100Gi"
              volumeType = "gp3"
              encrypted  = true
            }
          }
        ]
      })
      nodeClassRef = optional(any, {
        group = "karpenter.k8s.aws"
        kind  = "EC2NodeClass"
        name  = "gpu"
      }),
      requirements = optional(any, [
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"] # amd64 linux is main platform arch we will use
        },
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = ["spot", "on-demand"] # both spot and on-demand nodes, it will look at first available spot and if no then on-demand
        }
      ])
      disruption = optional(any, {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "1m" # the frequency how often karpenter will check and colocate/disrupt nodes
        budgets = [
          { nodes : "10%" } # allows karpenter to only deprovision/disrupt/recreate 10% of nodes at a time for consolidation/cost-optimization, to have more stable workloads
        ]
      }),
      limits = optional(any, {
        cpu = 1000
      })
    }), {})
  })
  default     = {}
  description = "Configurations to pass and override default ones for karpenter-nodes chart. Check the helm chart available configs here: https://github.com/dasmeta/helm/tree/karpenter-nodes-0.1.0/charts/karpenter-nodes"
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

variable "ami_alias" {
  type        = string
  default     = "al2023@latest"
  description = <<-EOT
    Declarative AMI selection for the default EC2NodeClass, in `family@version` form
    (for example `al2023@latest` or a pinned `al2023@v20240807`). The ami family implies `amiFamily`,
    so that field is not set separately for the default node class.

    IMPORTANT -- `@latest` means node replacement is CONTINUOUS AND UNATTENDED, not something that happens
    when you run terraform. Karpenter resolves the alias itself and re-checks AMI data on its own interval
    (chart default `amiRefreshInterval: 1m`). When AWS publishes a new EKS-optimised AMI -- typically every
    few weeks, sooner for CVEs -- karpenter marks existing nodes Drifted within about a minute and begins
    replacing them. Terraform's only role is setting this string; everything after that is karpenter.

    That replacement is voluntary disruption, so it IS paced by the node pool disruption budgets and IS
    suppressed during `var.disruption_windows`. It rolls a fraction of nodes at a time, outside your
    protected hours, rather than all at once.

    Pin to a specific version (`al2023@v20240807`) to stop drift entirely. Nodes then receive no AMI patches
    until someone moves the pin, so this trades unattended security patching for change control. Choose it
    when node replacement must be scheduled by a human, and put a recurring task in place to move the pin.

    This replaces deriving the AMI from an arbitrary running instance, which changed only on apply but chose
    unpredictably and drifted every node at once when it did.
  EOT
}

variable "disruption_windows" {
  type = list(object({
    schedule = string                                               # cron expression for when the window OPENS, interpreted in UTC only (karpenter does not support timezones)
    duration = string                                               # how long the window stays open, compound duration such as "12h" or "10h30m"
    reasons  = optional(list(string), ["Drifted", "Underutilized"]) # which voluntary disruption reasons are blocked; "Empty" is deliberately not blocked by default since removing an empty node disrupts nothing
    nodes    = optional(string, "0")                                # how many nodes may be disrupted while the window is open; "0" blocks the listed reasons entirely
  }))
  default = [
    {
      schedule = "0 6 * * mon-fri" # 06:00 UTC weekdays, roughly 08:00 in central Europe
      duration = "12h"             # through 18:00 UTC, roughly 20:00 in central Europe
      reasons  = ["Drifted", "Underutilized"]
      nodes    = "0"
    }
  ]
  description = <<-EOT
    Time windows during which voluntary node disruption is suppressed, rendered as NodePool disruption budgets.
    The default protects ordinary European business hours.

    IMPORTANT: karpenter evaluates these schedules in UTC only and does not support timezones, so this default
    is offset by an hour across European daylight saving and is wrong for other regions. Override it per setup.

    These budgets gate VOLUNTARY disruption only. They never delay spot interruption handling, and they never
    delay node expiry. Set to `[]` to disable windowing entirely.

    OVERRIDE SEMANTICS: a node pool that declares its own `disruption.budgets` in var.resource_configs owns
    them completely and these windows are NOT appended to it. Karpenter resolves multiple budgets
    most-restrictive-wins, so appending would silently narrow a hand-tuned window rather than defer to it.
    Only pools that express no budget opinion receive the module default plus these windows.
  EOT
}

variable "termination_grace_period" {
  type        = string
  default     = null
  description = <<-EOT
    Upper bound on how long a node may take to drain before karpenter removes the remaining pods and
    terminates it. Unset by default, and that default is deliberate.

    READ THIS BEFORE SETTING IT. Configuring a terminationGracePeriod does not merely bound a drain that has
    already started -- it changes what karpenter is willing to disrupt in the first place. Karpenter's
    documentation is explicit: nodes with active `karpenter.sh/do-not-disrupt` pods are "conditionally
    excluded from Drift", and "if the Node's owning NodeClaim has a terminationGracePeriod configured, it
    will still be eligible for disruption via drift". Once the period elapses, pods are force-deleted, and
    that "includes pods with blocking pod disruption budgets or the karpenter.sh/do-not-disrupt annotation".

    So setting this converts both protections from absolute into a delay:

      unset  -> a node hosting a do-not-disrupt pod or a blocking PDB is NEVER drifted. It keeps its old AMI
                until a human moves the workload.
      set    -> that node IS drifted, and the protected pods are force-deleted when the period expires.

    Leaving it unset is the safer position: a workload marked always-up stays up, and the node simply keeps
    an older AMI until someone handles it deliberately -- often with a prepared flow that cools the workload
    down, replaces the node and brings it back. Losing that workload to an unattended AMI roll is worse than
    running an older AMI for a few days.

    The cost is that a node with a genuinely broken budget can stay Deleting indefinitely. Fix the budget
    rather than setting this: the base chart refuses to render a zero-eviction PDB, and section E1 of
    `scripts/eks-assess.sh` lists any that already exist.

    Set it only on a cluster with a known stuck-node problem you cannot fix at source, and understand that you
    are trading away the guarantee that do-not-disrupt and PDBs are honoured.
  EOT
}

variable "protected_node_pool" {
  type = object({
    enabled      = optional(bool, false)                    # whether to create the protected on-demand node pool; off by default because on-demand capacity has real cost
    name         = optional(string, "protected")            # name of the created NodePool
    weight       = optional(number, 10)                     # scheduling preference relative to other pools; higher wins for pods that tolerate the taint
    taint_key    = optional(string, "dasmeta.io/protected") # taint key applied to the nodes so ordinary workloads never land here
    taint_value  = optional(string, "true")                 # taint value paired with taint_key
    limits       = optional(any, { cpu = 100 })             # upper bound on the capacity this pool may provision
    requirements = optional(any, null)                      # optional override of the instance requirements; defaults to the standard set restricted to on-demand
  })
  default     = {}
  description = <<-EOT
    Opt-in on-demand node pool for workloads that must not be moved by spot reclamation: ingress controllers,
    monitoring, single-replica and stateful services. Nodes carry a taint so only workloads that explicitly
    tolerate it are scheduled here. The pool uses `WhenEmpty` consolidation and is excluded from
    `var.disruption_windows`, since it should only ever lose genuinely empty nodes.
    Disabled by default so no consumer pays for capacity they did not ask for.
  EOT
}
