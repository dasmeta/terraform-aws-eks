terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      version = ">= 4.7.0"
    }
    helm = ">= 2.0"
    kubernetes = {
      version = "~>2.18"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~>1.14"
    }
  }
}
