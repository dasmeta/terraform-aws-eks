module "yaml" {
  source  = "dasmeta/helpers/null//modules/yaml"
  version = "0.0.1"

  files = [
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/v0.25.0/deploy/upstream/quickstart/crds.yaml",
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/v0.25.0/deploy/upstream/quickstart/olm.yaml"
  ]
}

resource "kubernetes_manifest" "olm" {
  for_each = toset(module.yaml.yamls)

  # provider = kubernetes-alpha

  manifest = yamldecode(each.value)
}
