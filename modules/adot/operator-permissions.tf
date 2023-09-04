locals {
  files = [
    "${path.module}/files/Namespace.yaml",
    "${path.module}/files/Role.yaml",
    "${path.module}/files/RoleBinding.yaml",
    "${path.module}/files/ClusterRoleBinding.yaml",
    "${path.module}/files/ClusterRole.yaml"
  ]
}

resource "kubernetes_namespace" "operator" {
  metadata {
    name = "opentelemetry-operator-system"
    labels = {
      "control-plane" = "controller-manager"
    }
  }
}

resource "kubectl_manifest" "this" {
  count = length(local.files)

  yaml_body  = file(local.files[count.index])
  apply_only = true
}
