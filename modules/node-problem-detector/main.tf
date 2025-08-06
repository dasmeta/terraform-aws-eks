module "node-problem-detector" {
  source  = "terraform-module/release/helm"
  version = "2.8.2"

  namespace  = "kube-system"
  repository = "https://charts.deliveryhero.io/"

  app = {
    name          = "node-problem-detector"
    version       = var.chart_version
    chart         = "node-problem-detector"
    force_update  = true
    wait          = true
    recreate_pods = false
    deploy        = 1
  }
  values = [jsonencode(var.configs)]
}
