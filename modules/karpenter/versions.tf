terraform {
  required_version = ">= 1.3.0"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    helm = ">= 2.0"
  }
}
