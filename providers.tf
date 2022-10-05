provider "kubernetes" {
  host                   = try(module.eks-cluster[0].host, null)
  cluster_ca_certificate = try(module.eks-cluster[0].certificate, null)
  token                  = try(module.eks-cluster[0].token, null)
  # load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = try(module.eks-cluster[0].host, null)
    cluster_ca_certificate = try(module.eks-cluster[0].certificate, null)
    token                  = try(module.eks-cluster[0].token, null)
  }
}
