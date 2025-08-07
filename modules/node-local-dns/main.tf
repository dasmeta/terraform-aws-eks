module "this" {
  source  = "terraform-module/release/helm"
  version = "2.8.2"

  namespace  = var.namespace
  repository = "oci://ghcr.io/deliveryhero/helm-charts"

  app = {
    name          = "node-local-dns"
    version       = var.chart_version
    chart         = "node-local-dns"
    force_update  = true
    wait          = var.wait
    recreate_pods = false
    deploy        = 1
  }
  values = [jsonencode(module.custom_default_configs.merged)]
}

data "kubernetes_service" "dns_service" {
  metadata {
    name      = var.core_dns_service_name
    namespace = var.namespace # the namespace should be exact the one where core-dns/kube-dns service created, by default it is `kube-system`
  }
}


module "custom_default_configs" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
    {
      config = {
        dnsServer = data.kubernetes_service.dns_service.spec[0].cluster_ip # set kube/core dns service IP here as this is required
      }
    },
    var.configs
  ]
}
