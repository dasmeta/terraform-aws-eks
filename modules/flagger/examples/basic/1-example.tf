module "this" {
  source = "../.."

  configs = {
    meshProvider = "nginx"
    prometheus = {
      install = true # most possibly the prometheus is already installed, in that case set this to false and use `metricsServer` option to set the endpoint to prometheus
    }
  }
}
