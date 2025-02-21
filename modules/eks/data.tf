data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster.cluster_name
}

data "aws_iam_user" "user_arn" {
  for_each  = { for user in var.users : user.username => user }
  user_name = each.value.username
}
