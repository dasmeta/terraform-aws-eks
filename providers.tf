provider "kubernetes" {
  host                   = module.eks-cluster.host
  cluster_ca_certificate = module.eks-cluster.certificate
  token                  = module.eks-cluster.token
  # load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = module.eks-cluster.host
    cluster_ca_certificate = module.eks-cluster.certificate
    token                  = module.eks-cluster.token
  }
}
