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
        # GPU nodes take minutes to become useful -- instance boot, driver initialisation and a container
        # image that is frequently tens of gigabytes. Tearing one down a minute after a job ends means the
        # next job pays that cost again, so a short value here trades real money for job latency. Note this
        # is NOT a stability trade: the policy above is WhenEmpty, and an empty node has nothing to disrupt.
        consolidateAfter = optional(string, "10m")
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
    Defaults applied to every karpenter node pool and node class, in two buckets: `default` for ordinary
    workloads and `gpu` for GPU node classes.

    Every field is individually optional, so setting one leaves its siblings on their defaults -- overriding
    `disruption.consolidateAfter` keeps `consolidationPolicy` and the protection window rather than dropping
    them.

    NOTE: only the keys `default` and `gpu` are accepted here. Terraform silently drops object attributes a
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

