terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      version = ">= 4.7.0"
    }
    helm = ">= 2.0"
    kubernetes = {
      version = "~>2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~>1.14"
    }
  }
}
