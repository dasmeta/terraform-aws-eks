resource "kubernetes_namespace" "example" {
  metadata {
    name = "meta-syatem"
  }
  depends_on = [
    module.adot
  ]
}
