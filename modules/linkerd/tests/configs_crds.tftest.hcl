mock_provider "helm" {}
mock_provider "tls" {}

run "forwards_crd_chart_values" {
  command = plan

  variables {
    configs_crds = {
      installGatewayAPI = true
    }
  }

  assert {
    condition = jsondecode(
      helm_release.this_crds[0].values[0]
    ).installGatewayAPI == true
    error_message = "The linkerd-crds release must receive configs_crds values."
  }
}
