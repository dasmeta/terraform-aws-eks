/**
 * # Why
 *
 * To spin up complete eks with all necessary components.
 * Those include:
 * - vpc (NOTE: the vpc submodule moved into separate repo https://github.com/dasmeta/terraform-aws-vpc)
 * - eks cluster
 * - alb ingress controller
 * - fluentbit
 * - external secrets
 * - metrics to cloudwatch
 *
 * ## How to run
 * ```hcl
*data "aws_availability_zones" "available" {}
*
*locals {
*    cluster_endpoint_public_access = true
*    cluster_enabled_log_types = ["audit"]
*  vpc = {
*    create = {
*      name = "dev"
*      availability_zones = data.aws_availability_zones.available.names
*      private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
*      public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
*      cidr               = "172.16.0.0/16"
*      public_subnet_tags = {
*    "kubernetes.io/cluster/dev" = "shared"
*    "kubernetes.io/role/elb"    = "1"
*  }
*  private_subnet_tags = {
*    "kubernetes.io/cluster/dev"       = "shared"
*    "kubernetes.io/role/internal-elb" = "1"
*  }
*    }
*  }
*   cluster_name = "your-cluster-name-goes-here"
*  alb_log_bucket_name = "your-log-bucket-name-goes-here"
*
*  fluent_bit_name = "fluent-bit"
*  log_group_name  = "fluent-bit-cloudwatch-env"
*}
*
*
*#(Basic usage with example of using already created VPC)
*data "aws_availability_zones" "available" {}
*
*locals {
*    cluster_endpoint_public_access = true
*    cluster_enabled_log_types = ["audit"]
*
*  vpc = {
*    link = {
*      id = "vpc-1234"
*      private_subnet_ids = ["subnet-1", "subnet-2"]
*    }
*  }
*   cluster_name = "your-cluster-name-goes-here"
*  alb_log_bucket_name = "your-log-bucket-name-goes-here"
*
*  fluent_bit_name = "fluent-bit"
*  log_group_name  = "fluent-bit-cloudwatch-env"
*}
*
*# Minimum
*
*module "cluster_min" {
*  source  = "dasmeta/eks/aws"
*  version = "0.1.1"
*
*  cluster_name        = local.cluster_name
*  users               = local.users
*
*  vpc = {
*    link = {
*      id = "vpc-1234"
*      private_subnet_ids = ["subnet-1", "subnet-2"]
*    }
*  }
*
*}
*
*# Max @TODO: the max param passing setup needs to be checked/fixed
*
* module "cluster_max" {
*  source  = "dasmeta/eks/aws"
*  version = "0.1.1"
*
*  ### VPC
*  vpc = {
*    create = {
*      name = "dev"
*     availability_zones = data.aws_availability_zones.available.names
*     private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
*     public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
*     cidr               = "172.16.0.0/16"
*     public_subnet_tags = {
*   "kubernetes.io/cluster/dev" = "shared"
*   "kubernetes.io/role/elb"    = "1"
*  }
*  private_subnet_tags = {
*    "kubernetes.io/cluster/dev"       = "shared"
*    "kubernetes.io/role/internal-elb" = "1"
*  }
*    }
*  }
*
*  cluster_enabled_log_types = local.cluster_enabled_log_types
*  cluster_endpoint_public_access = local.cluster_endpoint_public_access
*
*  ### EKS
*  cluster_name          = local.cluster_name
*  manage_aws_auth       = true
*
*  # IAM users username and group. By default value is ["system:masters"]
*  user = [
*          {
*            username = "devops1"
*            group    = ["system:masters"]
*          },
*          {
*            username = "devops2"
*            group    = ["system:kube-scheduler"]
*          },
*          {
*            username = "devops3"
*          }
*  ]
*
*  # You can create node use node_group when you create node in specific subnet zone.(Note. This Case Ec2 Instance havn't specific name).
*  # Other case you can use worker_group variable.
*
*  node_groups = {
*    example =  {
*      name  = "nodegroup"
*      name-prefix     = "nodegroup"
*      additional_tags = {
*          "Name"      = "node"
*          "ExtraTag"  = "ExtraTag"
*      }
*
*      instance_type   = "t3.xlarge"
*      max_capacity    = 1
*      disk_size       = 50
*      create_launch_template = false
*      subnet = ["subnet_id"]
*    }
* }
*
* node_groups_default = {
*     disk_size      = 50
*     instance_types = ["t3.medium"]
*   }
*
* worker_groups = {
*   default = {
*     name              = "nodes"
*     instance_type     = "t3.xlarge"
*     asg_max_size      = 3
*     root_volume_size  = 50
*   }
* }
*
*  workers_group_defaults = {
*    launch_template_use_name_prefix = true
*    launch_template_name            = "default"
*    root_volume_type                = "gp2"
*    root_volume_size                = 50
*  }
*
*  ### ALB-INGRESS-CONTROLLER
*  alb_log_bucket_name = local.alb_log_bucket_name
*
*  ### FLUENT-BIT
*  fluent_bit_name = local.fluent_bit_name
*  log_group_name  = local.log_group_name
*
*  # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
*  ### METRICS-SERVER
*  # enable_metrics_server = false
*  metrics_server_name     = "metrics-server"
}
 * ```
 **/
