/**
 * # external-secrets controller
 *
 * Installs the [external-secrets](https://external-secrets.io/) controller via Helm and
 * provisions the AWS identity it runs as, so the cluster can sync AWS Secrets Manager values
 * into Kubernetes Secrets.
 *
 * The controller gets its identity from an EKS Pod Identity association (default) or from IRSA
 * (`attachment_method = "service_account_role_annotation"`). No IAM user or static access key is
 * created. The base role holds no Secrets Manager permissions at all - it may only
 * `sts:AssumeRole` the per-store roles named `<store_role_name_prefix>*`, which the
 * `external-secret-store` module creates and scopes to its own secret name prefix. Pass this
 * module's `controller_role_arn` output to those store modules to complete the chain.
 *
 * The chart source accepts either a Helm repository or a direct `.tgz` archive URL, and the
 * controller/webhook/cert-controller images can be pointed at a private registry.
 *
 * ## Basic usage
 *
 * This submodule is normally consumed through the root EKS module rather than directly:
 *
 * ```terraform
 * module "eks" {
 *   source  = "dasmeta/eks/aws"
 *   version = "2.28.0"
 *
 *   cluster_name = "example"
 *
 *   external_secrets = {
 *     enabled = true
 *   }
 * }
 * ```
 *
 * To use it on its own:
 *
 * ```terraform
 * module "external_secrets" {
 *   source  = "dasmeta/eks/aws//modules/external-secrets"
 *   version = "2.28.0"
 *
 *   cluster_name = "example"
 * }
 * ```
 *
 * ## Pod Identity and pod restarts
 *
 * Credentials reach the controller through environment variables that EKS Pod Identity injects
 * when a pod is admitted, so a pod that was already running when the identity was created or
 * changed never receives them and fails every store assume-role call with `AccessDenied`.
 * Nothing restarts those pods on its own - the association is external to the pod, and a Helm
 * values change does not necessarily alter the pod template. This module therefore annotates all
 * three pod templates with the controller role ARN, so any identity change rolls the
 * deployments and the replacement pods get the credentials injected. If sync still fails after
 * an apply, restarting `external-secrets`, `external-secrets-webhook` and
 * `external-secrets-cert-controller` is the fallback.
 */

resource "helm_release" "this" {
  name             = var.release_name
  repository       = local.chart_is_url ? null : var.chart.repository
  chart            = var.chart.name
  version          = local.chart_is_url ? null : var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait
  timeout          = var.timeout

  # Later entries win in Helm: base config, then image overrides, then caller values/extras.
  values = [
    jsonencode(local.base_values),
    jsonencode(local.image_values),
    jsonencode(var.values),
    jsonencode(var.extra_values),
  ]

  # Ensure the controller's AWS identity exists before its pods start, so they can obtain
  # credentials immediately instead of failing until the next retry.
  depends_on = [aws_eks_pod_identity_association.this]
}
