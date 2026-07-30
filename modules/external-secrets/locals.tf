locals {
  # A direct .tgz endpoint is detected by an http(s) scheme in chart.name; in that case the
  # repository/version are dropped (the archive is self-describing).
  chart_is_url = can(regex("^https?://", var.chart.name))

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

  base_values = {
    installCRDs    = var.install_crds
    serviceAccount = local.service_account_values
  }

  # IAM attachment mode switches (same idiom as the aws-load-balancer-controller module).
  use_service_account_annotation    = var.attachment_method == "service_account_role_annotation"
  create_pod_identity_association   = var.attachment_method == "pod_identity_association"
  create_external_pod_identity_role = var.attachment_method == null

  oidc_provider_arn = local.use_service_account_annotation ? coalesce(var.oidc_provider_arn, try(data.aws_iam_openid_connect_provider.this[0].arn, null)) : null
  oidc_provider_id  = local.use_service_account_annotation ? replace(try(local.oidc_provider_arn, ""), "/.*id//", "") : ""

  iam_role_name = coalesce(var.iam_role_name, "external-secrets-${var.cluster_name}")

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
