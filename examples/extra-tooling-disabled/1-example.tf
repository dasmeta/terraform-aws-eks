module "this" {
  source = "../.."

  cluster_name = "test-with-extra-tooling-disabled"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  # enable_olm = true
  alarms                       = local.disabled
  enable_ebs_driver            = false
  enable_external_secrets      = false
  enable_node_problem_detector = false
  autoscaling                  = false
  karpenter                    = local.disabled
  keda                         = local.disabled
  linkerd                      = local.disabled
  kyverno                      = local.disabled

  # enabled components
  alb_load_balancer_controller = {
    enabled = true
    configs = {
      replicaCount = 1
    }
  }
  external_dns = {
    enabled = true
  }

  node_groups = {
    default = {
      min_size       = 1
      max_size       = 1
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }
}


resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.15"
  wait       = true

  values = [file("${path.module}/http-echo-extra-tooling-disabled.yaml")]

  depends_on = [module.this]
}
