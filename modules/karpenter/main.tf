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
  version = "20.30.1"

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
}

# installs karpenter operator helm package
resource "helm_release" "this" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(merge({
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
      featureGates = {
        spotToSpotConsolidation = true
      }
    }
    resources = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "100m"
        memory = "256Mi"
      }
    }
  }, var.configs))]
}

# allows to create karpenter crd resources such as NodeClasses, NodePools
resource "helm_release" "karpenter_nodes" {
  name             = "karpenter-node-classes"
  repository       = "https://dasmeta.github.io/helm"
  chart            = "karpenter-nodes"
  namespace        = var.namespace
  version          = var.resource_chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(merge(
    var.resource_configs,
    {
      ec2NodeClasses          = local.ec2NodeClasses
      nodePools               = local.nodePools
      karpenterServiceAccount = module.this.service_account
      karpenterNamespace      = var.namespace
    }
  ))]

  depends_on = [helm_release.this]
}
