terraform {
  required_version = ">= 1.3.0"

  required_providers {
    helm       = "~> 2.0"
    kubernetes = "~> 2.0"
  }
}

# it is considered that KUBECONFIG/KUBE_CONFIG_PATH env variables are set to point to kubernetes cluster where helm the app will be installed
provider "helm" {}
provider "kubernetes" {}
