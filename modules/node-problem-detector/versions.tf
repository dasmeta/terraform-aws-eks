terraform {
  required_version = ">= 1.0.0"
  required_providers {
    helm = ">= 2.0"
    # kubernetes = {
    #   version = "~>2.12"
    # }
    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "~>1.14"
    # }
  }
}
