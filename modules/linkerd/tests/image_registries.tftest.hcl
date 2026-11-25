mock_provider "helm" {}
mock_provider "tls" {}

run "uses_ghcr_without_losing_proxy_resources" {
  command = apply

  assert {
    condition = alltrue([
      try(jsondecode(helm_release.this.values[0]).controllerImage, "") == "ghcr.io/linkerd/controller",
      try(jsondecode(helm_release.this.values[0]).proxy.image.name, "") == "ghcr.io/linkerd/proxy",
      try(jsondecode(helm_release.this.values[0]).proxyInit.image.name, "") == "ghcr.io/linkerd/proxy-init",
      try(jsondecode(helm_release.this.values[0]).debugContainer.image.name, "") == "ghcr.io/linkerd/debug",
      try(jsondecode(helm_release.this_viz[0].values[0]).defaultRegistry, "") == "ghcr.io/linkerd",
    ])
    error_message = "Every default Linkerd image repository must use GHCR."
  }

  assert {
    condition     = jsondecode(helm_release.this.values[0]).proxy.resources == var.resourcesDefaults
    error_message = "Setting the proxy image must retain the existing proxy resource defaults."
  }
}

run "keeps_consumer_registry_overrides_last" {
  command = apply

  variables {
    configs = {
      controllerImage = "registry.example.com/linkerd/controller"
      proxy = {
        image = { name = "registry.example.com/linkerd/proxy" }
      }
      proxyInit = {
        image = { name = "registry.example.com/linkerd/proxy-init" }
      }
      debugContainer = {
        image = { name = "registry.example.com/linkerd/debug" }
      }
    }
    configs_viz = {
      defaultRegistry = "registry.example.com/linkerd"
    }
  }

  assert {
    condition = (
      length(helm_release.this.values) == 2 &&
      helm_release.this.values[1] == jsonencode(var.configs) &&
      length(helm_release.this_viz[0].values) == 2 &&
      helm_release.this_viz[0].values[1] == jsonencode(var.configs_viz)
    )
    error_message = "Consumer registry overrides must remain intact as the final Helm values entry."
  }
}
