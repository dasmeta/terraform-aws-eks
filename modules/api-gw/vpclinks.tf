data "aws_region" "this" {}

data "aws_subnet" "selected" {
  count = length(local.subnet_ids)
  id    = local.subnet_ids[count.index]
}

resource "aws_apigatewayv2_vpc_link" "example" {
  name               = var.vpc_link_name != null ? var.vpc_link_name : "vpc-link-${var.cluster_name}-${data.aws_region.this.name}"
  security_group_ids = [aws_security_group.api-gw-sg.id]
  subnet_ids         = var.subnet_ids
}

resource "aws_security_group" "api-gw-sg" {
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
