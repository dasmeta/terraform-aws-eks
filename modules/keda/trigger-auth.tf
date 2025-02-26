resource "kubectl_manifest" "keda_trigger_authentication" {
  yaml_body = templatefile("${path.module}/keda_trigger_auth.tpl", {
    namespace = var.namespace
  })
}

resource "kubectl_manifest" "keda_trigger_authentication_additional" {
  yaml_body = var.keda_trigger_auth_additional
}
