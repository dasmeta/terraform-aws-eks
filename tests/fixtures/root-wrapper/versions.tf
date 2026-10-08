terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws        = { source = "hashicorp/aws" }
    helm       = { source = "hashicorp/helm" }
    kubernetes = { source = "hashicorp/kubernetes" }
    kubectl    = { source = "gavinbunney/kubectl" }
  }
}
