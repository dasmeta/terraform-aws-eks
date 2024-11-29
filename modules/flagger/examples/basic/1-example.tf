module "this" {
  source = "../.."

  configs = {
    meshProvider = "nginx"
    prometheus = {
      install = true # most possibly the prometheus is already installed, in that case set this to false and use `metricsServer` option to set the endpoint to prometheus
    }
    slack = {
      url     = "https://hooks.slack.com/services/xxx/yyyy/zzz"
      channel = "#test-canary-notifications"
      user    = "Flagger"
    }
  }
  enable_metric_template = true
}
