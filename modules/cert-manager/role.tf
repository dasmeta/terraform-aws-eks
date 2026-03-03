# Create a single shared IAM policy for all issuers (combines permissions from all issuers)
resource "aws_iam_policy" "dns01_route53" {
  name        = "${var.cluster_name}-${data.aws_region.current.name}-cert-manager-dns01-route53"
  description = "Permissions for cert-manager DNS01 to manage Route53 records"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = length(local.all_hosted_zone_arns) > 0 ? local.all_hosted_zone_arns : ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create a single shared IAM role for all issuers (cert-manager service account can only have one role annotation)
module "dns01_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.28.0"

  role_name = "${var.cluster_name}-${data.aws_region.current.name}-cert-manager-dns01"

  role_policy_arns = {
    route53 = aws_iam_policy.dns01_route53.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:cert-manager"]
    }
  }
}
