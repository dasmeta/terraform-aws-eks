module "jenkins" {
  source  = "terraform-module/release/helm"
  version = "2.6.0"

  namespace  = "kube-system"
  repository = "https://charts.deliveryhero.io/"

  app = {
    name          = "node-problem-detector"
    version       = "1.5.0"
    chart         = "node-problem-detector"
    force_update  = true
    wait          = true
    recreate_pods = false
    deploy        = 1
  }
  values = [templatefile("${path.module}/values.yaml", {
    # region                = var.region
    # storage               = "4Gi"
  })]

  set = [
    # {
    #   name  = "labels.kubernetes\\.io/name"
    #   value = "jenkins"
    # },
    # {
    #   name  = "service.labels.kubernetes\\.io/name"
    #   value = "jenkins"
    # },
  ]

  set_sensitive = [
    # {
    #   path  = "master.adminUser"
    #   value = "jenkins"
    # },
  ]
}
