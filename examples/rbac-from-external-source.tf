module "roles" {
  source = "from some sorce that controlled by security specialist"
}

module "bindings" {
  source = "from some sorce that controlled by security specialist"
}

module "terraform-aws-eks" {
  source             = "../terraform-aws-eks"
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  cidr               = "172.16.0.0/16"
  cluster_name       = "my-cluster-sso"
  private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  users = [{
    username = "macos"
  }]
  vpc_name        = "eks-vpc"
  enable_sso_rbac = true

  roles    = module.roles
  bindings = module.bindings
}
