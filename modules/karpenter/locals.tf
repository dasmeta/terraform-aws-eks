locals {
  # get ami family dynamically based on ami id
  amiFamily = (
    (strcontains(data.aws_ami.this.name, "al2023") || strcontains(data.aws_ami.this.description, "Amazon Linux 2023")) ? "AL2023" :
    (strcontains(data.aws_ami.this.name, "amzn2") || strcontains(data.aws_ami.this.description, "AmazonLinux2")) ? "AL2" :
    null
  )
  # We create this aws ec2 node class as default for karpenter as this is something general and can be used as default for node-pools which have not nodeClassRef required field set explicitly
  defaultEc2NodeClass = {
    amiFamily           = coalesce(var.resource_configs_defaults.nodeClass.amiFamily, local.amiFamily) # ami family should be get automatically, but it can be also passed for node class
    role                = module.this.node_iam_role_name
    subnetSelectorTerms = [for id in var.subnet_ids : { id = id }]
    securityGroupSelectorTerms = [
      { tags = { "karpenter.sh/discovery" = var.cluster_name, "Name" = "${var.cluster_name}-node" } }
    ]
    amiSelectorTerms = [
      { id = data.aws_instance.ec2_from_eks_node_pool.ami }
    ]
    detailedMonitoring  = var.resource_configs_defaults.nodeClass.detailedMonitoring
    metadataOptions     = var.resource_configs_defaults.nodeClass.metadataOptions
    blockDeviceMappings = var.resource_configs_defaults.nodeClass.blockDeviceMappings
  }

  nodePoolDefaultNodeClassRef = var.resource_configs_defaults.nodeClassRef
  nodePoolDefaultRequirements = var.resource_configs_defaults.requirements

  nodePools = { for key, value in try(var.resource_configs.nodePools, {}) : key => merge(
    value,
    {
      template = merge(try(value.template, {}), {
        spec = merge({ nodeClassRef = local.nodePoolDefaultNodeClassRef }, try(value.template.spec, {}), {
          requirements = concat([for item in local.nodePoolDefaultRequirements : item if !contains(try(value.template.spec.requirements, []).*.key, item.key)], try(value.template.spec.requirements, []))
          expireAfter  = try(value.template.spec.expireAfter, "Never")
        })
      })
      disruption = merge(var.resource_configs_defaults.disruption, try(value.disruption, {}))
      limits     = merge(var.resource_configs_defaults.limits, try(value.limits, {}))
    }
  ) }
}
