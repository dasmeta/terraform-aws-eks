resource "helm_release" "portainer" {
  name             = "portainer"
  repository       = "https://portainer.github.io/k8s/"
  chart            = "portainer"
  version          = var.chart_version
  create_namespace = true
  namespace        = "portainer"

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "tls.force"
    value = "true"
  }

  set {
    name  = "ingress.enabled"
    value = "true" ? var.enable_ingress : "false"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
    value = "portainer"
  }

  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{'HTTPS':443}]"
  }

  set {
    name  = "ingress.hosts[0].host"
    value = local.host
  }

  set {
    name  = "ingress.hosts[0].paths[0].path"
    value = "/"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }

  set {
    name  = "persistence.storageClass"
    value = "gp2"
  }
}

locals {
  host = join("\\.", split(".", var.host))
}
