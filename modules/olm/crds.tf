module "yaml" {
  source  = "dasmeta/helpers/null//modules/yaml"
  version = "0.0.1"

  files = [
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/${var.version_tag}/deploy/upstream/quickstart/crds.yaml",
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/${var.version_tag}/deploy/upstream/quickstart/olm.yaml"
  ]
}

resource "kubernetes_manifest" "olm" {
  for_each = toset(module.yaml.yamls)

  manifest = yamldecode(each.value)
}
