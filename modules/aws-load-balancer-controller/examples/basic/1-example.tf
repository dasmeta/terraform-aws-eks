module "this" {
  source = "../.."

  cluster_name = "test-cluster-with-alb-controller"
  region       = "eu-central-1"

  chart = {
    version = "3.3.0"
  }
  configs = {
    replicaCount = 1
  }
}
