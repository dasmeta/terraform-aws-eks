module "this" {
  source = "../.."

  # A separate monitoring collector must provide CPU/memory/network/fs metrics.
  prometheus_cadvisor_enabled = false
}
