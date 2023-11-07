terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      version = ">= 5.24.0"
    }
    helm = ">= 2.0"
    kubernetes = {
      version = "~>2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~>1.14"
    }
  }
}
