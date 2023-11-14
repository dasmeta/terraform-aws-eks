resource "kubernetes_namespace" "meta-system" {
  metadata {
    name = "meta-system"
  }
}
