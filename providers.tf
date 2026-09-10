# Authentication uses the `exec` credential plugin rather than a `token` from `aws_eks_cluster_auth`.
#
# That data source mints a pre-signed STS token valid for exactly 15 minutes, once, and terraform cannot
# refresh it mid-apply. A first apply spends 8 minutes creating the cluster and 2 more on the node group
# before any kubernetes resource is attempted, so the token is already most of the way through its life
# before it is first used -- and any apply that runs longer than 15 minutes loses it outright. Both present
# identically and unhelpfully as `Unauthorized` or "the server has asked for the client to provide
# credentials", pointing at whichever resource happened to be next rather than at the credential.
#
# `exec` runs `aws eks get-token` at each API request instead, so the credential is minted when it is needed
# and cannot age out during a long apply.
#
# REQUIREMENT: the AWS CLI v2 must be on PATH wherever terraform runs, including CI runners.
locals {
  kube_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", local.region]
  }
}

provider "kubernetes" {
  host                   = try(module.eks-cluster[0].host, null)
  cluster_ca_certificate = try(module.eks-cluster[0].certificate, null)

  exec {
    api_version = local.kube_exec.api_version
    command     = local.kube_exec.command
    args        = local.kube_exec.args
  }
}

provider "kubectl" {
  host                   = try(module.eks-cluster[0].host, null)
  cluster_ca_certificate = try(module.eks-cluster[0].certificate, null)
  load_config_file       = false

  exec {
    api_version = local.kube_exec.api_version
    command     = local.kube_exec.command
    args        = local.kube_exec.args
  }
}

provider "helm" {
  kubernetes {
    host                   = try(module.eks-cluster[0].host, null)
    cluster_ca_certificate = try(module.eks-cluster[0].certificate, null)

    exec {
      api_version = local.kube_exec.api_version
      command     = local.kube_exec.command
      args        = local.kube_exec.args
    }
  }
}
