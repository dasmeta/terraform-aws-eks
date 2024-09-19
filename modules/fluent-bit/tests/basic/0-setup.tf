terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.37"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.23"
    }
    helm = ">= 2.0"
  }
}

provider "aws" {}
provider "helm" {}
provider "kubernetes" {}
