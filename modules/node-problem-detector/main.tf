module "node-problem-detector" {
  source  = "terraform-module/release/helm"
  version = "2.6.0"

  namespace  = "kube-system"
  repository = "https://charts.deliveryhero.io/"

  app = {
    name          = "node-problem-detector"
    version       = "2.3.5"
    chart         = "node-problem-detector"
    force_update  = true
    wait          = true
    recreate_pods = false
    deploy        = 1
  }
  values = [templatefile("${path.module}/values.yaml", {})]

  set = []

  set_sensitive = []
}
