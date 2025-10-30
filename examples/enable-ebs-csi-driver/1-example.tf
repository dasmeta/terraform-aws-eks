module "this" {
  source = "../.."

  cluster_name = "test-eks-ebs-csi-driver-enabled"
  node_groups = {
    regular = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  # we do disable the following components to have some basic/clear cluster, to have only minimal needed components for this example
  autoscaling                  = false
  enable_external_secrets      = false
  create_cert_manager          = false
  enable_node_problem_detector = false
  metrics_exporter             = "disabled"
  fluent_bit_configs = {
    enabled = false
  }
  nginx_ingress_controller_config = {
    enabled = false
  }
  karpenter = {
    enabled = false
  }
  keda = {
    enabled = false
  }
  linkerd = {
    enabled = false
  }

  alarms = { enabled = false }

  alb_load_balancer_controller = {
    enabled = false
  }

  external_dns = {
    enabled = false
  }

  kyverno = {
    enabled = false
  }

  # enabled components
  enable_ebs_driver = true # enables ebs csi driver and creates ebs-gp2, ebs-gp3(this will be default), ebs-io2-3k, ebs-io2-8k ...  storage classed based on it
}

# app/container with non root linux user read/write to mounted volume
resource "helm_release" "http_echo_with_volumes" {
  name       = "http-echo-with-volumes"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.14"
  wait       = true

  values = [file("${path.module}/http-echo-with-volumes.yaml")]

  depends_on = [module.this]
}

# app/container with root linux user read/write to mounted volume
resource "helm_release" "nginx_with_volumes" {
  name       = "nginx-with-volumes"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.14"
  wait       = true

  values = [file("${path.module}/nginx-with-volumes.yaml")]

  depends_on = [module.this]
}
