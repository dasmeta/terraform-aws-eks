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
