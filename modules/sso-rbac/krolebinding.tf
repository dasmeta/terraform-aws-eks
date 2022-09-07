resource "kubernetes_role_binding" "example" {

  for_each = { for bind in var.bindings : "${bind.namespace}-${bind.group}" => bind }


  metadata {
    name      = each.key
    namespace = each.value.namespace
  }

  subject {
    kind      = "Group" #Kind - User/Group
    name      = each.value.group     #Group/User to bind
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.key
  }
}
