data "aws_region" "this" {}

data "aws_subnet" "selected" {
  count = var.api_gateway_resources[0].vpc_links != null ? length(local.subnet_ids) : 0
  id    = local.subnet_ids[count.index]
}

resource "kubernetes_manifest" "vpc_link" {
  #for_each = { for link in flatten([for api in var.api_gateway_resources : api.vpc_links]) : link.name => link }
  for_each = { for link in flatten([for api in var.api_gateway_resources : api.vpc_links != null ? api.vpc_links : []]) : link.name => link }
  manifest = {
    apiVersion = "apigatewayv2.services.k8s.aws/v1alpha1"
    kind       = "VPCLink"
    metadata = {
      name      = each.value.name
      namespace = each.value.namespace != null ? each.value.namespace : "default"
    }
    spec = {
      name             = each.value.name
      securityGroupIDs = [aws_security_group.api-gw-sg[0].id]
      subnetIDs        = var.subnet_ids
    }
  }
}

resource "aws_security_group" "api-gw-sg" {
  count       = var.api_gateway_resources[0].vpc_links != null ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "aws-api-gw-${var.cluster_name}-${data.aws_region.this.name}-sg"
  description = "Allow traffic from EKS to API gateway"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  subnet_ids = var.subnet_ids
  cidrs      = [for s in data.aws_subnet.selected : s.cidr_block]
}
