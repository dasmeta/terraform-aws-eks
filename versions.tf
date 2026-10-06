terraform {
  # 1.8 is the real floor, not a preference. Two things in the module require it:
  #   - provider::deepmerge::mergo in locals.tf -- provider-defined functions landed in Terraform 1.8
  #   - strcontains in modules/karpenter/locals.tf -- added in Terraform 1.5
  # The previous "~> 1.3" was already understated: a consumer on 1.3 fails on the deepmerge call, which
  # sits on the root path every consumer evaluates. Raising this is a deliberate compatibility change that
  # makes the declaration match what the code has needed since the addon merge was introduced.
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.31, < 6.0.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    deepmerge = {
      source  = "isometry/deepmerge"
      version = "~> 1.1"
    }

    utils = {
      source  = "cloudposse/utils"
      version = "2.1.0"
    }

  }
}
