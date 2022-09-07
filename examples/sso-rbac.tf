module "sso-rbac" {

  count = var.enable_sso_rbac ? 1 : 0

  source = "./modules/sso-rbac"

  roles      = local.roles
  bindings   = local.bindings
  eks_module = module.eks-cluster
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
