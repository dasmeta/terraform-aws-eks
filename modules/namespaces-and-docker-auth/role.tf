data "aws_secretsmanager_secret" "this" {
  count = var.configs.dockerAuth.enabled ? 1 : 0

  name = var.configs.dockerAuth.secretManagerSecretName
}

resource "aws_iam_policy" "this" {
  count = var.configs.dockerAuth.enabled ? 1 : 0

  name        = "${var.cluster_name}-${var.configs.dockerAuth.name}"
  path        = "/"
  description = "Policy allowing to fetch docker registry auth credentials from aws secret manager"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource" : data.aws_secretsmanager_secret.this[0].arn
      }
    ]
  })
}

module "dockerhub_auth_secret_iam_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.53.0"

  count = var.configs.dockerAuth.enabled ? 1 : 0

  role_name = "${var.cluster_name}-${var.configs.dockerAuth.name}"
  role_policy_arns = {
    policy = resource.aws_iam_policy.this[0].arn
  }

  oidc_providers = {
    one = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.configs.dockerAuth.name}"]
    }
  }
}
