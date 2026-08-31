# NOTE: the aws_instances/aws_instance/aws_ami lookups that used to derive the default node class AMI from an
# arbitrary running instance were removed. They made AMI selection a function of live infrastructure rather than
# configuration, so an unrelated apply could change the fleet's target image and drift every node at once.
# The default node class now uses a declarative `alias` selector, see var.ami_alias.

data "aws_ami" "gpu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-nvidia-${var.cluster_version}-*"]
  }
  # Only EKS official AMIs are owned by AWS account 602401143452
  owners = ["602401143452"]
}
