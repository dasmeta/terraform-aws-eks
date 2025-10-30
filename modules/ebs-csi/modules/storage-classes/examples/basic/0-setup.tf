terraform {
  required_version = "~> 1.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# to run this example there is need to set env variable with existing eks cluster `export KUBE_CONFIG_PATH=/path/to/eks/cluster.kubeconfig`
provider "kubernetes" {}
