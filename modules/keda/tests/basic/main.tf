module "keda" {
  source = "../../"

  name             = "keda"
  eks_cluster_name = "buycycle-cluster"
  attach_policies  = { "sqs" : true }
}
