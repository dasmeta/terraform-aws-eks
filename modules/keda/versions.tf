terraform {
  required_version = ">= 1.3.0" # Ensure Terraform version compatibility

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # This ensures compatibility with AWS provider v5
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~>1.14"
    }
  }
}
