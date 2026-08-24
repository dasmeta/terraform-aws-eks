
resource "aws_iam_policy" "this" {
  name        = local.iam_policy_name
  description = local.iam_policy_description
  policy      = file("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws-load-balancer-role" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.use_service_account_annotation ? [
        {
          Effect = "Allow"
          Principal = {
            Federated = local.oidc_provider_arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "oidc.eks.${var.region}.amazonaws.com/id/${local.oidc_provider_id}:aud" = "sts.amazonaws.com"
              "oidc.eks.${var.region}.amazonaws.com/id/${local.oidc_provider_id}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            }
          }
        }
      ] : [],
      (local.create_pod_identity_association || local.create_external_pod_identity_role) ? [
        {
          Effect = "Allow"
          Principal = {
            Service = "pods.eks.amazonaws.com"
          }
          Action = [
            "sts:AssumeRole",
            "sts:TagSession"
          ]
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.aws-load-balancer-role.name
}

# The association is created before the Helm release (see the release's depends_on) so the
# controller pods can obtain credentials on first start. Pod Identity injects the credential
# environment variables at admission time, so an association created after the pods are already
# running never reaches them and every ELB call fails until they are restarted by hand. The
# association does not require the namespace or the service account to exist yet, so creating it
# first has no ordering problem of its own.
resource "aws_eks_pod_identity_association" "this" {
  count = local.create_pod_identity_association ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.aws-load-balancer-role.arn
}

# IAM and STS are eventually consistent: a role that was just created and a policy that was just
# attached are not necessarily effective on the data plane the moment the API call returns. The
# controller issues its first AWS calls seconds after the release lands, and a call denied inside
# that window leaves the ingress with a stale AccessDenied condition that only a pod restart
# clears, because controller-runtime backs the failing reconcile off to its 1000s ceiling. Holding
# the release back for a short window after the identity wiring is in place removes the race.
# The triggers make this a one-time wait: it re-runs only when the identity itself changes.
resource "time_sleep" "iam_propagation" {
  count = var.iam.propagation_delay == "0s" ? 0 : 1

  create_duration = var.iam.propagation_delay

  triggers = {
    role_arn          = aws_iam_role.aws-load-balancer-role.arn
    policy_attachment = aws_iam_role_policy_attachment.AWSLoadBalancerControllerIAMPolicy.id
    pod_identity      = local.create_pod_identity_association ? aws_eks_pod_identity_association.this[0].association_arn : "none"
  }
}
