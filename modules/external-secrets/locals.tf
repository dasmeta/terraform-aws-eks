locals {
  # A direct .tgz endpoint is detected by an http(s) scheme in chart.name; in that case the
  # repository/version are dropped (the archive is self-describing).
  chart_is_url = can(regex("^https?://", var.chart.name))
  region       = coalesce(var.region, try(data.aws_region.this[0].name, null))

  # Full image repository path: "<registry>/<repository>" when a registry override is set,
  # else just "<repository>". Only emitted when a repository override is present.
  image_repository = try(var.image.repository, null) != null ? (
    try(var.image.registry, null) != null ? "${var.image.registry}/${var.image.repository}" : var.image.repository
  ) : null

  image_block = merge(
    local.image_repository != null ? { repository = local.image_repository } : {},
    try(var.image.tag, null) != null ? { tag = var.image.tag } : {},
  )

  # external-secrets, its webhook and cert-controller all share the same image by default;
  # apply the same override to each. When image_block is empty these are no-op empty maps and
  # the chart's own image defaults are used (empty maps merge without setting any keys).
  image_values = {
    image          = local.image_block
    webhook        = { image = local.image_block }
    certController = { image = local.image_block }
  }

  # Pod Identity hands credentials to a pod through environment variables injected at admission
  # time, and IRSA works off the service account bound at pod creation. Either way a pod that was
  # already running when the identity changed keeps its old (or absent) credentials and fails
  # every assume-role call, and neither a Helm value change nor the association itself restarts
  # it. Stamping the identity onto the pod templates makes any identity change roll the three
  # deployments, so the new pods pick the credentials up. The ARN is stable once created, so this
  # does not churn on later applies. Hashed only to keep the annotation short - it is not secret.
  # The `checksum/` prefix follows the convention Helm charts use for exactly this purpose
  # (`checksum/config`, `checksum/secret`), so it stays vendor neutral.
  identity_annotation = { "checksum/aws-identity" = sha1(aws_iam_role.this.arn) }

  base_values = {
    installCRDs    = var.install_crds
    serviceAccount = local.service_account_values
    podAnnotations = local.identity_annotation
    webhook        = { podAnnotations = local.identity_annotation }
    certController = { podAnnotations = local.identity_annotation }
  }

  # IAM attachment mode switches (same idiom as the aws-load-balancer-controller module).
  use_service_account_annotation    = var.attachment_method == "service_account_role_annotation"
  create_pod_identity_association   = var.attachment_method == "pod_identity_association"
  create_external_pod_identity_role = var.attachment_method == null

  oidc_provider_arn = local.use_service_account_annotation ? coalesce(var.oidc_provider_arn, try(data.aws_iam_openid_connect_provider.this[0].arn, null)) : null
  oidc_provider_id  = local.use_service_account_annotation ? replace(try(local.oidc_provider_arn, ""), "/.*id//", "") : ""

  iam_role_name = coalesce(var.iam_role_name, "external-secrets-${var.cluster_name}-${local.region}")

  # Per-store IAM roles the controller is allowed to assume (role chaining), matched by name prefix.
  store_role_arn_pattern = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.store_role_name_prefix}*"

  # For IRSA, annotate the chart-created SA with the role ARN. For Pod Identity, no annotation.
  service_account_values = merge(
    { create = true, name = var.service_account_name },
    local.use_service_account_annotation ? {
      annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn }
    } : {}
  )
}
