locals {
  attachment_method                 = var.iam.attachment_method
  use_service_account_annotation    = local.attachment_method == "service_account_role_annotation"
  create_pod_identity_association   = local.attachment_method == "pod_identity_association"
  create_external_pod_identity_role = local.attachment_method == null
  oidc_provider_arn                 = coalesce(var.oidc_provider_arn, try(data.aws_iam_openid_connect_provider.this[0].arn, null))
  oidc_provider_id                  = replace(try(local.oidc_provider_arn, ""), "/.*id//", "")

  use_direct_chart = startswith(var.chart.name, "http://") || startswith(var.chart.name, "https://")

  chart_repository = local.use_direct_chart ? null : var.chart.repository

  image_overrides = merge(
    var.image.repository != null ? { repository = var.image.repository } : {},
    var.image.tag != null ? { tag = var.image.tag } : {}
  )

  generated_iam_policy_name = var.iam.use_descriptive_names ? "aws-load-balancer-controller-${var.cluster_name}" : "${var.cluster_name}-alb-management"
  generated_iam_role_name   = var.iam.use_descriptive_names ? "aws-load-balancer-controller-${var.cluster_name}_iam_role" : var.cluster_name

  iam_policy_name        = coalesce(var.iam.policy_name, local.generated_iam_policy_name)
  iam_policy_description = coalesce(var.iam.policy_description, "Permissions that are required to manage AWS Application Load Balancers.")
  iam_role_name          = coalesce(var.iam.role_name, local.generated_iam_role_name)

  service_account_values = merge(
    {
      name = var.service_account_name
    },
    local.use_service_account_annotation ? {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.aws-load-balancer-role.arn
      }
    } : {}
  )

  default_values = merge(
    {
      clusterName    = var.cluster_name
      serviceAccount = local.service_account_values
      enableWaf      = var.enable_waf
      enableWafv2    = var.enable_waf
      vpcId          = var.vpc_id
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
    },
    length(local.image_overrides) > 0 ? {
      image = local.image_overrides
    } : {}
  )
}
