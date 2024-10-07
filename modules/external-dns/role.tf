module "role" {
  source  = "dasmeta/iam/aws//modules/role"
  version = "1.2.1"

  name        = "${var.cluster_name}-external-dns"
  description = "${var.cluster_name} eks cluster external-dns role"

  policy = [
    {
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = ["arn:aws:route53:::hostedzone/*"]
    },
    {
      actions = [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ]
      resources = ["*"]
    }
  ]

  trust_relationship = [
    {
      principals = {
        type        = "Service"
        identifiers = ["eks.amazonaws.com"]
      },
      actions = ["sts:AssumeRole"]
    },
    {
      principals = {
        type        = "Federated"
        identifiers = ["${var.oidc_provider_arn}"]
      },
      actions = ["sts:AssumeRoleWithWebIdentity"]
      conditions = [
        {
          type  = "StringEquals"
          key   = "${local.oidc_provider}:aud"
          value = ["sts.amazonaws.com"]
        },
        {
          type  = "StringEquals"
          key   = "${local.oidc_provider}:sub"
          value = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
        }
      ]
    }
  ]
}
