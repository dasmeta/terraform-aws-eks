# select an random ec2 instance from eks node pools to get its ami id for using in karpenter
data "aws_instances" "ec2_from_eks_node_pools" {
  filter {
    name   = "tag:karpenter.sh/discovery"
    values = [var.cluster_name]
  }

  instance_state_names = ["running"]
}

data "aws_instance" "ec2_from_eks_node_pool" {
  instance_id = data.aws_instances.ec2_from_eks_node_pools.ids[0]
}

data "aws_ami" "this" {
  most_recent = true
  filter {
    name   = "image-id"
    values = [data.aws_instance.ec2_from_eks_node_pool.ami]
  }
}

data "aws_ami" "gpu" {
  most_recent = true

  # filter {
  #   name   = "name"
  #   values = [try(var.resource_configs_defaults["gpu"].nodeClass.ami_name, "amazon-eks-gpu-node-1.32-v20251120")]
  # }
  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${var.cluster_version}-*"]
  }
  # Only EKS official AMIs are owned by AWS account 602401143452
  owners = ["602401143452"]
}
