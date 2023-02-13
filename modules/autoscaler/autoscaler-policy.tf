resource "aws_iam_policy" "policy" {
  name        = "AmazonEKSClusterAutoscalerPolicy"
  path        = "/"
  description = "Amazon EKS Autoscaler Policy"

  policy = file("${path.module}/policies/cluster-autoscaler-policy.json")
}
