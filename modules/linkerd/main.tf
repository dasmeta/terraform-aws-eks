/**
 *
 * # terraform module allows to create/deploy linkerd into eks cluster
 * TODOs:
 *  - check and set more default values for default setup, for example the plain helm charts components do not have resources requests/limits and in low resource situations this can result some issues
 *  - consider moving this submodule to general/shared module as this module is not eks specific and it can be used with any k8s setup
 *
 * ## basic usage example
 * ```terraform
 * module "this" {
 *   source  = "dasmeta/eks/aws//modules/linkerd"
 *   version = "2.22.0"
 * }
 * ```
 *
 *
**/

# installs linkerd operator crds helm package
resource "helm_release" "this_crds" {
  count = var.crds_create ? 1 : 0

  name             = "linkerd-crds"
  repository       = var.chart_repository
  chart            = "linkerd-crds"
  namespace        = var.namespace
  version          = var.crds_chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait

  values = [jsonencode(var.configs_crds)]
}

# installs linkerd operator helm package
resource "helm_release" "this" {
  name             = "linkerd-control-plane"
  repository       = var.chart_repository
  chart            = "linkerd-control-plane"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = false
  atomic           = var.atomic
  wait             = var.wait
  skip_crds        = true

  values = [jsonencode(local.default_configs), jsonencode(var.configs)]

  depends_on = [helm_release.this_crds]
}

# installs linkerd viz helm package, which provides monitoring tooling like prometheus and web ui to check linkerd enabled pods info
resource "helm_release" "this_viz" {
  count = var.viz_create ? 1 : 0

  name             = "linkerd-viz"
  repository       = var.chart_repository
  chart            = "linkerd-viz"
  namespace        = "${var.namespace}-viz"
  version          = var.viz_chart_version
  create_namespace = var.create_namespace
  atomic           = var.atomic
  wait             = var.wait
  skip_crds        = true

  values = [jsonencode(local.default_configs_viz), jsonencode(var.configs_viz)]

  depends_on = [helm_release.this]
}
