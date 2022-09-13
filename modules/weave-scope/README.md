This module will enable `Weave-Scope` in EKS if `enable_weave_scope` is set to `true`
## Usage
```
module "terraform-aws-eks" {
  source = "../terraform-aws-eks"
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  cidr = "172.16.0.0/16"
  cluster_name = "my-cluster-sso"
  private_subnets = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  users = [{
    username = "macos"
  }]
  vpc_name = "eks-vpc"
  alb_log_bucket_name = "bucket-eks-miandevops-temporary"

  enable_weave_scope = true
}
```