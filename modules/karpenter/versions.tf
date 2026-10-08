terraform {
  # strcontains, used to read the bootstrap family off the discovered AMI in locals.tf, was added in
  # Terraform 1.5. The root module requires 1.8 for its provider-defined deepmerge function.
  required_version = ">= 1.5.0"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    helm = ">= 2.0"
  }
}
