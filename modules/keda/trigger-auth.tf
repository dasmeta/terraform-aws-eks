resource "kubectl_manifest" "keda_trigger_authentication" {
  yaml_body = templatefile("${path.module}/keda_trigger_auth.tpl", {
    namespace = var.namespace
  })
}

resource "kubectl_manifest" "keda_trigger_authentication_additional" {
  count     = var.keda_trigger_auth_additional != null ? 1 : 0
  yaml_body = var.keda_trigger_auth_additional
}
