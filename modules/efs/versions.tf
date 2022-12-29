terraform {
  required_providers {
    helm = ">= 2.0"
  }

  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "~> 2.12"
  }
}
