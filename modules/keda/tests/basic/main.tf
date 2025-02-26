module "keda" {
  source = "../../"

  name             = "keda"
  eks_cluster_name = "buycycle-cluster"
  scaling_type     = "sqs"
}
