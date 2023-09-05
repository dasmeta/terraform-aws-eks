module "vpc" {
  source  = "dasmeta/vpc/aws"
  version = "1.0.1"

  count = try(var.vpc.create.name) != null ? 1 : 0

  name                = var.vpc.create.name
  availability_zones  = var.vpc.create.availability_zones
  cidr                = var.vpc.create.cidr
  private_subnets     = var.vpc.create.private_subnets
  public_subnets      = var.vpc.create.public_subnets
  public_subnet_tags  = var.vpc.create.public_subnet_tags
  private_subnet_tags = var.vpc.create.private_subnet_tags
}
