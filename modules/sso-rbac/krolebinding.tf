resource "kubernetes_role_binding" "example" {

  for_each = { for bind in var.bindings : "${bind.namespace}-${bind.group}" => bind }


  metadata {
    name      = each.value.group
    namespace = each.value.namespace
  }

  subject {
    kind      = "Group"
    name      = each.value.group
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.key
  }
}
