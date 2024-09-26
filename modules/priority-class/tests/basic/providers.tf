locals {
  cluster_name = "stage"
}

data "aws_eks_cluster" "test-cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "test-cluster" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "test-cluster-oidc-provider" {
  url = data.aws_eks_cluster.test-cluster.identity[0].oidc[0].issuer
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.test-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.test-cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.test-cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "--region", "eu-central-1", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}
