/**
 * # Creates aws load balancer controller on eks cluster
 *
 * # todo
 * - automate shell script contents via terraform
 * - test and remove waf related values from helm
 * - re-consider namespace
 *
 * https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/
 *
 */

resource "helm_release" "aws-load-balancer-controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [
    jsonencode(
      {
        clusterName = var.cluster_name
        serviceAccount = {
          name = var.service_account_name
          annotations = {
            "eks.amazonaws.com/role-arn" = "arn:aws:iam::${var.account_id}:role/${aws_iam_role.aws-load-balancer-role.name}"
          }
        }
        enableWaf   = var.enable_waf
        enableWafv2 = var.enable_waf
        vpcId       = var.vpc_id
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          }
        ]
      }
    ),
    jsonencode(var.configs)
  ]
}
