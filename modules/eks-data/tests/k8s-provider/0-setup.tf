terraform {
  required_providers {

    test = {
      source = "terraform.io/builtin/test"
    }

    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.0"
      configuration_aliases = []
    }

    kubectl = {
      source                = "gavinbunney/kubectl"
      version               = "1.14.0"
      configuration_aliases = []
    }

  }

  required_version = ">= 1.3.0"
}
/**
 * set the following env vars so that aws provider will get authenticated before apply:

 export AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxxxxx
 export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
*/
provider "aws" {
  region = "eu-central-1"
}
