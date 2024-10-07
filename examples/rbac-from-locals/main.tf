module "this" {
  source = "../../"

  cluster_name = "eks-test-rbac-from-locals"

  vpc = {
    create = {
      name               = "test-eks-spot-instances"
      cidr               = "172.16.0.0/16"
      availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
      private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
      public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
    }
  }

  users = [{
    username = "macos"
  }]
  enable_sso_rbac = true

  weave_scope_config = {
    namespace        = "weave"
    create_namespace = true
    ingress_class    = "ingressClass"
    ingress_host     = "www.example.com"
    annotations = {
      "key1" = "value1"
      "key2" = "value2"
    }
    service_type            = "NodePort"
    weave_helm_release_name = "weave"
  }

  weave_scope_enabled = true

  roles    = local.roles
  bindings = local.bindings

  alarms = {
    enabled   = false
    sns_topic = ""
  }
}

locals {

  roles = [{
    name      = "viewers"
    actions   = ["get", "list", "watch"]
    resources = ["deployments"]
    }, {
    name      = "editors"
    actions   = ["get", "list", "watch"]
    resources = ["pods"]
  }]

  bindings = [{
    group     = "developers"
    namespace = "development"
    roles     = ["viewers", "editors"]

    }, {
    group     = "accountants"
    namespace = "accounting"
    roles     = ["editors"]
    },
    {
      group     = "developers"
      namespace = "accounting"
      roles     = ["viewers"]
    }
  ]
}
