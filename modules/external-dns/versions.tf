terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      version = ">= 4.7.0"
    }
    helm = ">= 2.0"
  }
}
