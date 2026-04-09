
resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-alb-management"
  description = "Permissions that are required to manage AWS Application Load Balancers."
  policy      = file("${path.module}/iam-policy.json")
}

resource "aws_iam_role" "aws-load-balancer-role" {
  name = var.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${var.region}.amazonaws.com/id/${var.eks_oidc_root_ca_thumbprint}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AWSLoadBalancerControllerIAMPolicy" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.aws-load-balancer-role.name
}
