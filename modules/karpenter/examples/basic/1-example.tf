module "this" {
  source = "../.."

  cluster_name      = "test-cluster-with-karpenter"
  cluster_endpoint  = "<endpoint-to-eks-cluster>"
  oidc_provider_arn = "<eks-oidc-provider-arn>"
  subnet_ids        = ["<subnet-1>", "<subnet-2>", "<subnet-3>"]

  resource_configs = {
    nodePools = {
      general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
      on-demand = {
        # weight = 0 # by default the weight is 0 and this is lowest priority, we can schedule pod in this not
        template = {
          spec = {
            requirements = [
              {
                key      = "karpenter.sh/capacity-type"
                operator = "In"
                values   = ["on-demand"]
              }
            ]
          }
        }
      }
    }
  }
}
