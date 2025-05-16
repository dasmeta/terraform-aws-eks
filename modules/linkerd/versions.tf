terraform {
  required_version = ">= 1.3.0"

  required_providers {
    helm = ">= 2.0"
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
