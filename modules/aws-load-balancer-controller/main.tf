/**
 * # Creates aws load balancer controller on eks cluster
 *
 * Docs and supported ingress annotations:
 * https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/
 *
 * ## Identity wiring and pod restarts
 *
 * The controller receives its AWS credentials once, when its pod starts: with IRSA the annotated
 * service account is bound into the pod's projected token at creation, and with EKS Pod Identity
 * the agent injects the credential environment variables at admission. A pod that starts before
 * the role, its policy attachment or the Pod Identity association exist never gets working
 * credentials, and nothing brings it back on its own - the ingress keeps reporting
 * `AccessDenied` on calls like `elasticloadbalancing:DescribeLoadBalancers` even though the
 * policy is visibly attached to the role, and only a pod restart clears it.
 *
 * This module therefore:
 *
 * - creates the role, the policy attachment and the Pod Identity association *before* the Helm
 *   release, so the identity is complete by the time the first pod starts;
 * - waits `iam.propagation_delay` after that wiring, because IAM and STS are eventually
 *   consistent and a just-attached policy is not necessarily effective the instant the API
 *   returns (set it to `"0s"` to skip the wait);
 * - stamps the identity onto the pod template as a `checksum/aws-identity` annotation, so any
 *   later change to the role or its policy attachment rolls the deployment and the replacement
 *   pods pick the new credentials up.
 */

resource "helm_release" "aws-load-balancer-controller" {
  name             = "aws-load-balancer-controller"
  repository       = local.chart_repository
  chart            = var.chart.name
  version          = var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [
    jsonencode(local.default_values),
    jsonencode(var.configs)
  ]

  # The controller pods must not start before the identity they run as is complete. The role ARN
  # is referenced through the values, but the policy attachment and the Pod Identity association
  # have no implicit edge to this release and would otherwise be created in parallel with it.
  depends_on = [
    aws_iam_role_policy_attachment.AWSLoadBalancerControllerIAMPolicy,
    aws_eks_pod_identity_association.this,
    time_sleep.iam_propagation,
  ]
}
