/**
 *
 *  # terraform module allows to create/deploy karpenter operator to have custom/configurable node auto-scaling ability
 * ## for more info check https://karpenter.sh and https://artifacthub.io/packages/helm/karpenter/karpenter
 *
 *
 * ## example
 * ```terraform
 * module "karpenter" {
 *   source  = "dasmeta/eks/aws//modules/karpenter"
 *   version = "2.19.0"
 *
 *   cluster_name      = "test-cluster-with-karpenter"
 *   cluster_endpoint  = "<endpoint-to-eks-cluster>"
 *   oidc_provider_arn = "<eks-oidc-provider-arn>"
 *   subnet_ids        = ["<subnet-1>", "<subnet-2>", "<subnet-3>"]
 *
 *   resource_configs = {
 *       nodePools = {
 *         general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
 *         on-demand = {
 *           # weight = 0 # by default the weight is 0 and this is lowest priority, we can schedule pod in this not
 *           template = {
 *             spec = {
 *               requirements = [
 *                 {
 *                   key      = "karpenter.sh/capacity-type"
 *                   operator = "In"
 *                   values   = ["on-demand"]
 *                 }
 *               ]
 *             }
 *           }
 *         }
 *       }
 *     }
 * }
 * ```
 *
 *
**/


# creates aws eks karpenter needed policy/role/queue/event-subscriber resources to use in karpenter helm
module "this" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.37.2"

  node_iam_role_name                = "Karpenter-${substr(var.cluster_name, 0, 25)}-"
  cluster_name                      = var.cluster_name
  irsa_oidc_provider_arn            = var.oidc_provider_arn
  enable_v1_permissions             = var.enable_v1_permissions
  enable_pod_identity               = var.enable_pod_identity
  create_pod_identity_association   = var.create_pod_identity_association
  node_iam_role_additional_policies = var.node_iam_role_additional_policies
  enable_irsa                       = true
  create_instance_profile           = true
  create_node_iam_role              = true

  # Our two extra actions are attached as a SEPARATE managed policy (below) rather than through
  # `iam_policy_statements`, which would inline them into the upstream document. See that resource for why.
  iam_role_policies = {
    unscoped_read = aws_iam_policy.controller_unscoped_read.arn
  }
}

# AWS caps a managed policy at 6144 characters, whitespace excluded. The upstream controller document is
# already 5966 of those for a 30-character cluster name, and the cluster name appears in it 16 times -- so
# every additional character of cluster name costs 16, and the 178 characters of headroom are gone once the
# name grows by 11. `iam_policy_statements` therefore is not a usable escape hatch: anything added there
# competes for a budget the cluster name already owns, and going over does not degrade gracefully. The policy
# fails to create, the controller has no permissions at all, and karpenter cannot launch a single instance --
# which surfaces as unrelated workloads hanging with nowhere to schedule.
#
# A separate managed policy gets its own 6144 budget and leaves the upstream document untouched.
#
# iam:ListInstanceProfiles   -- instance profile garbage collection, karpenter 1.9+. Cannot be scoped.
# ec2:DescribeInstanceStatus -- interruption-controller health checks, karpenter 1.12+. The pinned upstream
#                               version omits it from AllowRegionalReadActions, so without it that path fails
#                               with AccessDenied and the capability is silently absent.
#
# TODO: both are granted upstream from eks module v21.15.1+; drop this policy when that upgrade lands.
resource "aws_iam_policy" "controller_unscoped_read" {
  name_prefix = "KarpenterControllerRead-${substr(var.cluster_name, 0, 20)}-"
  description = "Unscoped read actions the karpenter controller needs that the pinned upstream policy omits"
  tags        = var.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowUnscopedReadActions"
        Effect   = "Allow"
        Action   = ["iam:ListInstanceProfiles", "ec2:DescribeInstanceStatus"]
        Resource = "*"
      }
    ]
  })
}

# installs karpenter operator crds helm package (we need this separate chart for crds, as the below main chart do not support crds upgrade, doc: https://karpenter.sh/docs/upgrading/upgrade-guide/#crd-upgrades)
resource "helm_release" "this_crds" {
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait

  depends_on = [module.this]
}

# installs karpenter operator helm package
resource "helm_release" "this" {
  # The upstream chart requires each karpenter replica to sit on a distinct node in a distinct availability
  # zone (required hostname podAntiAffinity + DoNotSchedule zone topologySpread + a nodeAffinity excluding
  # karpenter's own nodes). An unsatisfiable request does not fail: the extra replica simply stays Pending
  # forever, so the setup looks highly available while it is not. Subnet count is knowable here, so we fail
  # on it. Node count and their zone spread are not knowable at plan time and are documented instead.
  lifecycle {
    precondition {
      condition     = try(var.configs.replicas, 2) <= 1 || length(var.subnet_ids) >= 2
      error_message = "karpenter is configured with ${try(var.configs.replicas, 2)} replicas but only ${length(var.subnet_ids)} subnet(s) were provided. Each replica needs a separate node in a separate availability zone, so 2+ replicas require 2+ subnets. Either provide subnets in at least 2 availability zones, or set karpenter.configs.replicas = 1."
    }
  }

  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait
  skip_crds        = true

  values = [
    jsonencode({
      serviceAccount = {
        name = module.this.service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = module.this.iam_role_arn
        }
      }
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = module.this.queue_name
      }
      controller = {
        resources = local.controller_resources
      }
    }),
    jsonencode(var.configs)
  ]

  depends_on = [helm_release.this_crds]
}

# allows to create karpenter crd resources such as NodeClasses, NodePools
# Holds the karpenter controller alive for a window on DESTROY, so it can terminate the EC2 instances it owns.
#
# Deleting a NodePool marks its NodeClaims for deletion, but draining and terminating the instance is the
# controller's job, and terraform has no edge to those instances at all -- it never created them. Remove the
# controller first and the instances are orphaned, still holding the `-node` security group, so the destroy
# fails later on a security group whose real blocker is an EC2 instance nothing is tracking.
#
# Ordering matters and is easy to get backwards. This sleep is created AFTER the controller and BEFORE the
# node classes below, which on destroy gives: node classes (NodePools deleted) -> this wait -> controller.
# Hanging the sleep off the node classes instead would place the wait before the NodePools are deleted, which
# is useless.
#
# A fixed wait is a mitigation, not a guarantee: draining respects PodDisruptionBudgets and can outlast it.
# Delete the node pools and confirm `kubectl get nodeclaims` is empty before destroying for the reliable path.
resource "time_sleep" "karpenter_teardown" {
  depends_on = [helm_release.this]

  # Only on destroy. Creation is unaffected.
  #
  # 60s rather than the 30s used for the load balancer controller, because this one is not waiting on API
  # calls. Deleting a NodePool cascades to its NodeClaims, and each one cordons its node and evicts the pods,
  # respecting PodDisruptionBudgets and each pod's terminationGracePeriodSeconds. The bound is the workloads,
  # not the AWS API -- the recommended example alone sets grace periods of 45s and 60s, so a shorter wait
  # would cut its own drains short. Anything with long grace periods or tight budgets will still outlast
  # this; that is what the documented pre-destroy procedure is for.
  destroy_duration = "60s"
}

resource "helm_release" "karpenter_nodes" {
  name             = "karpenter-node-classes"
  repository       = "https://dasmeta.github.io/helm"
  chart            = "karpenter-nodes"
  namespace        = var.namespace
  version          = var.resource_chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  values = [
    jsonencode(merge( # TODO: check if this merge needed or we can have var.resource_configs with its own line in values
      var.resource_configs,
      {
        ec2NodeClasses = {
          default = local.defaultEc2NodeClass,
          gpu     = local.defaultEc2NodeClassGpu
        }
        nodePools               = local.nodePools
        karpenterServiceAccount = module.this.service_account
        karpenterNamespace      = var.namespace
      }
    )),
    jsonencode({ ec2NodeClasses = try(var.resource_configs.ec2NodeClasses, {}) })
  ]

  depends_on = [time_sleep.karpenter_teardown]
}
