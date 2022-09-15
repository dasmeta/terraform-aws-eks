resource "kubernetes_role_v1" "k8s-rbac" {

  for_each = { for bind in var.bindings : "${bind.namespace}-${bind.group}" => bind }

  metadata {
    name      = each.key
    namespace = each.value.namespace
  }

  dynamic "rule" {
    for_each = var.roles

    content {
      api_groups = [""]
      resources  = rule.value.resources
      verbs      = rule.value.actions
    }
  }
}
