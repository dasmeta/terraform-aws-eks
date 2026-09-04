module "keda" {
  source = "../../"

  name             = "keda"
  eks_cluster_name = "example-cluster"
  attach_policies  = { "sqs" : true }
}
