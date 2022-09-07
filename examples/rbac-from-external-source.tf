module "roles" {
  source = "from some sorce that controlled by security specialist"
}

module "assignments" {
  source = "from some sorce that controlled by security specialist"
}

module "eks" {
  source = "complete-cluster"

  roles       = module.roles.values
  assignments = module.assignments.values
}
