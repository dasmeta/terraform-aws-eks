mock_provider "helm" {}
mock_provider "tls" {}

run "forwards_generated_webhook_certs_to_control_plane_chart" {
  command = apply

  assert {
    condition = jsondecode(
      helm_release.this.values[0]
    ).proxyInjector.crtPEM != null
    error_message = "The linkerd-control-plane release must receive a generated proxyInjector.crtPEM instead of leaving Helm to self-generate an unrotated one."
  }

  assert {
    condition = jsondecode(
      helm_release.this.values[0]
      ).proxyInjector.caBundle == jsondecode(
      helm_release.this.values[0]
    ).proxyInjector.crtPEM
    error_message = "proxyInjector.caBundle must match proxyInjector.crtPEM (self-signed cert used as its own trust bundle)."
  }

  assert {
    condition = jsondecode(
      helm_release.this.values[0]
    ).profileValidator.crtPEM != null
    error_message = "The linkerd-control-plane release must receive a generated profileValidator.crtPEM instead of leaving Helm to self-generate an unrotated one."
  }

  assert {
    condition = jsondecode(
      helm_release.this.values[0]
    ).policyValidator.crtPEM != null
    error_message = "The linkerd-control-plane release must receive a generated policyValidator.crtPEM instead of leaving Helm to self-generate an unrotated one."
  }
}

# The module defaults and var.configs are passed as two separate values[]
# entries and left for Helm itself to deep-merge, rather than being merged
# Terraform-side. Helm merges the list in order with later entries winning, so
# the user-supplied configs must always come last.
run "passes_defaults_and_user_configs_as_separate_values_entries" {
  command = apply

  variables {
    configs = {
      proxyInjector = {
        keyPEM = "user-supplied-override"
      }
    }
    configs_viz = {
      dashboard = {
        replicas = 3
      }
    }
  }

  assert {
    condition     = length(helm_release.this.values) == 2
    error_message = "The linkerd-control-plane release must receive exactly two values entries: module defaults first, then var.configs."
  }

  assert {
    condition = jsondecode(
      helm_release.this.values[1]
    ).proxyInjector.keyPEM == "user-supplied-override"
    error_message = "var.configs must be forwarded verbatim as the last values entry so Helm's own merge lets it win over the module defaults."
  }

  assert {
    condition = jsondecode(
      helm_release.this.values[0]
    ).proxyInjector.crtPEM != null
    error_message = "The module defaults entry must still carry the generated certs when var.configs overrides a sibling key - Helm deep-merges the two, so unset sibling keys are preserved."
  }

  assert {
    condition = jsondecode(
      helm_release.this_viz[0].values[1]
    ).dashboard.replicas == 3
    error_message = "var.configs_viz must be forwarded verbatim as the last values entry of the linkerd-viz release."
  }
}
