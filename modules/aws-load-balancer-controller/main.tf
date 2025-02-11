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

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-alb-management"
  description = "Permissions that are required to manage AWS Application Load Balancers."
  policy      = file("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws-load-balancer-role" {
  name = var.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${var.region}.amazonaws.com/id/${var.eks_oidc_root_ca_thumbprint}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.aws-load-balancer-role.name
}

resource "helm_release" "aws-load-balancer-controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [jsonencode(module.custom_default_configs_merged.merged)]
}


module "custom_default_configs_merged" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
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
    },
    var.configs
  ]
}
