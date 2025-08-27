resource "helm_release" "this" {
  name             = "external-dns"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "external-dns"
  namespace        = var.namespace
  version          = var.chart_version
  create_namespace = var.create_namespace
  atomic           = true
  wait             = false

  values = [
    jsonencode(merge(
      {
        # NOTE: we set/switch image repository related to change in bitnami to remove the original bitnami org/repository dockerhub repos and migrate all existing/old images to bitnamilegacy, for more info check https://github.com/bitnami/containers/issues/83267
        # TODO: consider a change to use another image repository which is maintained
        global = {
          security = {
            allowInsecureImages = true
          }
        }
        image = {
          repository = "bitnamilegacy/external-dns"
        }
        aws = { region = local.region }
        serviceAccount = {
          create      = true
          name        = var.service_account_name
          annotations = { "eks.amazonaws.com/role-arn" = module.role.arn }
        }
      },
      var.configs
    ))
  ]

  depends_on = [
    module.role
  ]
}
