mock_provider "helm" {}
mock_provider "tls" {}

run "default_preserves_upstream_chart" {
  command = plan

  assert {
    condition     = length(helm_release.this_viz[0].postrender) == 0
    error_message = "The default must preserve the upstream chart without a postrenderer."
  }
}

run "disables_only_cadvisor_scrape" {
  command = plan

  variables {
    prometheus_cadvisor_enabled = false
  }

  assert {
    condition     = length(helm_release.this_viz[0].postrender) == 1
    error_message = "Disabling cAdvisor must configure the bounded postrenderer."
  }
}

run "disabled_viz_does_not_render" {
  command = plan

  variables {
    viz_create                 = false
    prometheus_cadvisor_enabled = false
  }

  assert {
    condition     = length(helm_release.this_viz) == 0
    error_message = "The opt-out must not create a disabled Viz release."
  }
}

run "disabled_prometheus_does_not_need_postrenderer" {
  command = plan

  variables {
    prometheus_cadvisor_enabled = false
    configs_viz = {
      prometheus = { enabled = false }
    }
  }

  assert {
    condition     = length(helm_release.this_viz[0].postrender) == 0
    error_message = "A disabled embedded Prometheus has no cAdvisor job to remove."
  }
}
