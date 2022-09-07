locals {
  roles = [
    {
      name      = "role1"
      actions   = ["get", "list", "watch"]
      resources = ["deployments"]
    },
    {
      name      = "role2"
      actions   = ["get", "list", "watch"]
      resources = ["pods"]
    }
  ]
}

module "eks" {
  source = "complete-cluster"

  roles       = module.roles.values
  assignments = module.assignments.values
}
