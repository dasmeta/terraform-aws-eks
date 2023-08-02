<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Why

To spin up complete eks with all necessary components.
Those include:
- vpc (NOTE: the vpc submodule moved into separate repo https://github.com/dasmeta/terraform-aws-vpc)
- eks cluster
- alb ingress controller
- fluentbit
- external secrets
- metrics to cloudwatch

## How to run
```hcl
*data "aws_availability_zones" "available" {}

*locals {
   cluster_endpoint_public_access = true
   cluster_enabled_log_types = ["audit"]
 vpc = {
   create = {
     name = "dev"
     availability_zones = data.aws_availability_zones.available.names
     private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
     public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
     cidr               = "172.16.0.0/16"
     public_subnet_tags = {
   "kubernetes.io/cluster/dev" = "shared"
   "kubernetes.io/role/elb"    = "1"
 }
 private_subnet_tags = {
   "kubernetes.io/cluster/dev"       = "shared"
   "kubernetes.io/role/internal-elb" = "1"
 }
   }
 }
  cluster_name = "your-cluster-name-goes-here"
 alb_log_bucket_name = "your-log-bucket-name-goes-here"

 fluent_bit_name = "fluent-bit"
 log_group_name  = "fluent-bit-cloudwatch-env"
*}

*#(Basic usage with example of using already created VPC)
*data "aws_availability_zones" "available" {}

*locals {
   cluster_endpoint_public_access = true
   cluster_enabled_log_types = ["audit"]

 vpc = {
   link = {
     id = "vpc-1234"
     private_subnet_ids = ["subnet-1", "subnet-2"]
   }
 }
  cluster_name = "your-cluster-name-goes-here"
 alb_log_bucket_name = "your-log-bucket-name-goes-here"

 fluent_bit_name = "fluent-bit"
 log_group_name  = "fluent-bit-cloudwatch-env"
*}

*# Minimum

*module "cluster_min" {
 source  = "dasmeta/eks/aws"
 version = "0.1.1"

 cluster_name        = local.cluster_name
 users               = local.users

 vpc = {
   link = {
     id = "vpc-1234"
     private_subnet_ids = ["subnet-1", "subnet-2"]
   }
 }

*}

*# Max @TODO: the max param passing setup needs to be checked/fixed

module "cluster_max" {
 source  = "dasmeta/eks/aws"
 version = "0.1.1"

 ### VPC
 vpc = {
   create = {
     name = "dev"
    availability_zones = data.aws_availability_zones.available.names
    private_subnets    = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
    public_subnets     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
    cidr               = "172.16.0.0/16"
    public_subnet_tags = {
  "kubernetes.io/cluster/dev" = "shared"
  "kubernetes.io/role/elb"    = "1"
 }
 private_subnet_tags = {
   "kubernetes.io/cluster/dev"       = "shared"
   "kubernetes.io/role/internal-elb" = "1"
 }
   }
 }

 cluster_enabled_log_types = local.cluster_enabled_log_types
 cluster_endpoint_public_access = local.cluster_endpoint_public_access

 ### EKS
 cluster_name          = local.cluster_name
 manage_aws_auth       = true

 # IAM users username and group. By default value is ["system:masters"]
 user = [
         {
           username = "devops1"
           group    = ["system:masters"]
         },
         {
           username = "devops2"
           group    = ["system:kube-scheduler"]
         },
         {
           username = "devops3"
         }
 ]

 # You can create node use node_group when you create node in specific subnet zone.(Note. This Case Ec2 Instance havn't specific name).
 # Other case you can use worker_group variable.

 node_groups = {
   example =  {
     name  = "nodegroup"
     name-prefix     = "nodegroup"
     additional_tags = {
         "Name"      = "node"
         "ExtraTag"  = "ExtraTag"
     }

     instance_type   = "t3.xlarge"
     max_capacity    = 1
     disk_size       = 50
     create_launch_template = false
     subnet = ["subnet_id"]
   }
}

node_groups_default = {
    disk_size      = 50
    instance_types = ["t3.medium"]
  }

worker_groups = {
  default = {
    name              = "nodes"
    instance_type     = "t3.xlarge"
    asg_max_size      = 3
    root_volume_size  = 50
  }
}

 workers_group_defaults = {
   launch_template_use_name_prefix = true
   launch_template_name            = "default"
   root_volume_type                = "gp2"
   root_volume_size                = 50
 }

 ### ALB-INGRESS-CONTROLLER
 alb_log_bucket_name = local.alb_log_bucket_name

 ### FLUENT-BIT
 fluent_bit_name = local.fluent_bit_name
 log_group_name  = local.log_group_name

 # Should be refactored to install from cluster: for prod it has done from metrics-server.tf
 ### METRICS-SERVER
 # enable_metrics_server = false
 metrics_server_name     = "metrics-server"
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.54.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.8.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_adot"></a> [adot](#module\_adot) | ./modules/adot | n/a |
| <a name="module_alb-ingress-controller"></a> [alb-ingress-controller](#module\_alb-ingress-controller) | ./modules/aws-load-balancer-controller | n/a |
| <a name="module_api-gw-controller"></a> [api-gw-controller](#module\_api-gw-controller) | ./modules/api-gw | n/a |
| <a name="module_autoscaler"></a> [autoscaler](#module\_autoscaler) | ./modules/autoscaler | n/a |
| <a name="module_cloudwatch-metrics"></a> [cloudwatch-metrics](#module\_cloudwatch-metrics) | ./modules/cloudwatch-metrics | n/a |
| <a name="module_ebs-csi"></a> [ebs-csi](#module\_ebs-csi) | ./modules/ebs-csi | n/a |
| <a name="module_efs-csi-driver"></a> [efs-csi-driver](#module\_efs-csi-driver) | ./modules/efs-csi | n/a |
| <a name="module_eks-cluster"></a> [eks-cluster](#module\_eks-cluster) | ./modules/eks | n/a |
| <a name="module_external-secrets"></a> [external-secrets](#module\_external-secrets) | ./modules/external-secrets | n/a |
| <a name="module_fluent-bit"></a> [fluent-bit](#module\_fluent-bit) | ./modules/fluent-bit | n/a |
| <a name="module_metrics-server"></a> [metrics-server](#module\_metrics-server) | ./modules/metrics-server | n/a |
| <a name="module_sso-rbac"></a> [sso-rbac](#module\_sso-rbac) | ./modules/sso-rbac | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | dasmeta/vpc/aws | 1.0.0 |
| <a name="module_weave-scope"></a> [weave-scope](#module\_weave-scope) | ./modules/weave-scope | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.cert-manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kube-state-metrics](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | `null` | no |
| <a name="input_adot_config"></a> [adot\_config](#input\_adot\_config) | n/a | `any` | <pre>{<br>  "accepte_namespace_regex": "(default|kube-system)",<br>  "additional_metrics": {}<br>}</pre> | no |
| <a name="input_alb_log_bucket_name"></a> [alb\_log\_bucket\_name](#input\_alb\_log\_bucket\_name) | n/a | `string` | `""` | no |
| <a name="input_alb_log_bucket_path"></a> [alb\_log\_bucket\_path](#input\_alb\_log\_bucket\_path) | ALB-INGRESS-CONTROLLER | `string` | `""` | no |
| <a name="input_api_gateway_resources"></a> [api\_gateway\_resources](#input\_api\_gateway\_resources) | Nested map containing API, Stage, and VPC Link resources | <pre>list(object({<br>    namespace = string<br>    api = object({<br>      name         = string<br>      protocolType = string<br>    })<br>    stages = list(object({<br>      name        = string<br>      apiRef_name = string<br>      stageName   = string<br>      autoDeploy  = bool<br>      description = string<br>    }))<br>    vpc_links = list(object({<br>      name = string<br>    }))<br>  }))</pre> | n/a | yes |
| <a name="input_api_gw_deploy_region"></a> [api\_gw\_deploy\_region](#input\_api\_gw\_deploy\_region) | Region in which API gatewat will be configured | `string` | `""` | no |
| <a name="input_autoscaler_image_patch"></a> [autoscaler\_image\_patch](#input\_autoscaler\_image\_patch) | The patch number of autoscaler image | `number` | `0` | no |
| <a name="input_autoscaler_limits"></a> [autoscaler\_limits](#input\_autoscaler\_limits) | n/a | <pre>object({<br>    cpu    = string<br>    memory = string<br>  })</pre> | <pre>{<br>  "cpu": "100m",<br>  "memory": "600Mi"<br>}</pre> | no |
| <a name="input_autoscaler_requests"></a> [autoscaler\_requests](#input\_autoscaler\_requests) | n/a | <pre>object({<br>    cpu    = string<br>    memory = string<br>  })</pre> | <pre>{<br>  "cpu": "100m",<br>  "memory": "600Mi"<br>}</pre> | no |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | Weather enable autoscaling or not in EKS | `bool` | `false` | no |
| <a name="input_bindings"></a> [bindings](#input\_bindings) | Variable which describes group and role binding | <pre>list(object({<br>    group     = string<br>    namespace = string<br>    roles     = list(string)<br><br>  }))</pre> | `[]` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html) | `list(string)` | <pre>[<br>  "audit"<br>]</pre> | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | n/a | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Creating eks cluster name. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Allows to set/change kubernetes cluster version, kubernetes version needs to be updated at leas once a year. Please check here for available versions https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html | `string` | `"1.23"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create cluster and other resources or not | `bool` | `true` | no |
| <a name="input_create_cert_manager"></a> [create\_cert\_manager](#input\_create\_cert\_manager) | If enabled it always gets deployed to the cert-manager namespace. | `bool` | `false` | no |
| <a name="input_ebs_csi_version"></a> [ebs\_csi\_version](#input\_ebs\_csi\_version) | EBS CSI driver addon version | `string` | `"v1.15.0-eksbuild.1"` | no |
| <a name="input_efs_id"></a> [efs\_id](#input\_efs\_id) | EFS filesystem id in AWS | `string` | `null` | no |
| <a name="input_enable_api_gw_controller"></a> [enable\_api\_gw\_controller](#input\_enable\_api\_gw\_controller) | Weather enable API-GW controller or not | `bool` | `false` | no |
| <a name="input_enable_ebs_driver"></a> [enable\_ebs\_driver](#input\_enable\_ebs\_driver) | Weather enable EBS-CSI driver or not | `bool` | `true` | no |
| <a name="input_enable_efs_driver"></a> [enable\_efs\_driver](#input\_enable\_efs\_driver) | Weather install EFS driver or not in EKS | `bool` | `false` | no |
| <a name="input_enable_kube_state_metrics"></a> [enable\_kube\_state\_metrics](#input\_enable\_kube\_state\_metrics) | Enable kube-state-metrics | `bool` | `false` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | METRICS-SERVER | `bool` | `false` | no |
| <a name="input_enable_sso_rbac"></a> [enable\_sso\_rbac](#input\_enable\_sso\_rbac) | Enable SSO RBAC integration or not | `bool` | `false` | no |
| <a name="input_external_secrets_namespace"></a> [external\_secrets\_namespace](#input\_external\_secrets\_namespace) | The namespace of external-secret operator | `string` | `"kube-system"` | no |
| <a name="input_fluent_bit_name"></a> [fluent\_bit\_name](#input\_fluent\_bit\_name) | FLUENT-BIT | `string` | `""` | no |
| <a name="input_log_group_name"></a> [log\_group\_name](#input\_log\_group\_name) | n/a | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | n/a | `number` | `90` | no |
| <a name="input_manage_aws_auth"></a> [manage\_aws\_auth](#input\_manage\_aws\_auth) | n/a | `bool` | `true` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br>    rolearn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_metrics_exporter"></a> [metrics\_exporter](#input\_metrics\_exporter) | Metrics Exporter, can use cloudwatch or adot | `string` | `"cloudwatch"` | no |
| <a name="input_metrics_server_name"></a> [metrics\_server\_name](#input\_metrics\_server\_name) | n/a | `string` | `"metrics-server"` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node group definitions to create | `any` | <pre>{<br>  "default": {<br>    "desired_size": 2,<br>    "iam_role_additional_policies": [<br>      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br>    ],<br>    "instance_types": [<br>      "t3.medium"<br>    ],<br>    "max_size": 4,<br>    "min_size": 2<br>  }<br>}</pre> | no |
| <a name="input_node_groups_default"></a> [node\_groups\_default](#input\_node\_groups\_default) | Map of EKS managed node group default configurations | `any` | <pre>{<br>  "disk_size": 50,<br>  "iam_role_additional_policies": [<br>    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br>  ],<br>  "instance_types": [<br>    "t3.medium"<br>  ]<br>}</pre> | no |
| <a name="input_node_security_group_additional_rules"></a> [node\_security\_group\_additional\_rules](#input\_node\_security\_group\_additional\_rules) | n/a | `any` | <pre>{<br>  "ingress_cluster_10250": {<br>    "description": "Metric server to node groups",<br>    "from_port": 10250,<br>    "protocol": "tcp",<br>    "self": true,<br>    "to_port": 10250,<br>    "type": "ingress"<br>  },<br>  "ingress_cluster_8443": {<br>    "description": "Metric server to node groups",<br>    "from_port": 8443,<br>    "protocol": "tcp",<br>    "source_cluster_security_group": true,<br>    "to_port": 8443,<br>    "type": "ingress"<br>  }<br>}</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | `null` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | Variable describes which role will user have K8s | <pre>list(object({<br>    actions   = list(string)<br>    resources = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_scale_down_unneeded_time"></a> [scale\_down\_unneeded\_time](#input\_scale\_down\_unneeded\_time) | Scale down unneeded in minutes | `number` | `2` | no |
| <a name="input_send_alb_logs_to_cloudwatch"></a> [send\_alb\_logs\_to\_cloudwatch](#input\_send\_alb\_logs\_to\_cloudwatch) | Whether send alb logs to CloudWatch or not. | `bool` | `true` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to open eks cluster api access | `list(any)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration for eks, we support both cases create new vpc(create field) and using already created one(link) | <pre>object({<br>    # for linking using existing vpc<br>    link = optional(object({<br>      id                 = string<br>      private_subnet_ids = list(string)<br>    }), { id = null, private_subnet_ids = null })<br>    # for creating new vpc<br>    create = optional(object({<br>      name                = string<br>      availability_zones  = list(string)<br>      cidr                = string<br>      private_subnets     = list(string)<br>      public_subnets      = list(string)<br>      public_subnet_tags  = optional(map(any), {})<br>      private_subnet_tags = optional(map(any), {})<br>    }), { name = null, availability_zones = null, cidr = null, private_subnets = null, public_subnets = null })<br>  })</pre> | n/a | yes |
| <a name="input_weave_scope_config"></a> [weave\_scope\_config](#input\_weave\_scope\_config) | Weave scope namespace configuration variables | <pre>object({<br>    create_namespace        = bool<br>    namespace               = string<br>    annotations             = map(string)<br>    ingress_host            = string<br>    ingress_class           = string<br>    ingress_name            = string<br>    service_type            = string<br>    weave_helm_release_name = string<br>  })</pre> | <pre>{<br>  "annotations": {},<br>  "create_namespace": true,<br>  "ingress_class": "",<br>  "ingress_host": "",<br>  "ingress_name": "weave-ingress",<br>  "namespace": "meta-system",<br>  "service_type": "NodePort",<br>  "weave_helm_release_name": "weave"<br>}</pre> | no |
| <a name="input_weave_scope_enabled"></a> [weave\_scope\_enabled](#input\_weave\_scope\_enabled) | Weather enable Weave Scope or not | `bool` | `false` | no |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | Worker groups. | `any` | `{}` | no |
| <a name="input_workers_group_defaults"></a> [workers\_group\_defaults](#input\_workers\_group\_defaults) | Worker group defaults. | `any` | <pre>{<br>  "launch_template_name": "default",<br>  "launch_template_use_name_prefix": true,<br>  "root_volume_size": 50,<br>  "root_volume_type": "gp2"<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate"></a> [cluster\_certificate](#output\_cluster\_certificate) | EKS cluster certificate used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_cluster_host"></a> [cluster\_host](#output\_cluster\_host) | EKS cluster host name used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | n/a |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | n/a |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | n/a |
| <a name="output_cluster_token"></a> [cluster\_token](#output\_cluster\_token) | EKS cluster token used for authentication/access in helm/kubectl/kubernetes providers |
| <a name="output_eks_auth_configmap"></a> [eks\_auth\_configmap](#output\_eks\_auth\_configmap) | n/a |
| <a name="output_eks_module"></a> [eks\_module](#output\_eks\_module) | n/a |
| <a name="output_eks_oidc_root_ca_thumbprint"></a> [eks\_oidc\_root\_ca\_thumbprint](#output\_eks\_oidc\_root\_ca\_thumbprint) | Grab eks\_oidc\_root\_ca\_thumbprint from oidc\_provider\_arn. |
| <a name="output_map_user_data"></a> [map\_user\_data](#output\_map\_user\_data) | n/a |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ## CLUSTER |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | n/a |
| <a name="output_role_arns_without_path"></a> [role\_arns\_without\_path](#output\_role\_arns\_without\_path) | n/a |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The cidr block of the vpc |
| <a name="output_vpc_default_security_group_id"></a> [vpc\_default\_security\_group\_id](#output\_vpc\_default\_security\_group\_id) | The ID of default security group created for vpc |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The newly created vpc id |
| <a name="output_vpc_nat_public_ips"></a> [vpc\_nat\_public\_ips](#output\_vpc\_nat\_public\_ips) | The list of elastic public IPs for vpc |
| <a name="output_vpc_private_subnets"></a> [vpc\_private\_subnets](#output\_vpc\_private\_subnets) | The newly created vpc private subnets IDs list |
| <a name="output_vpc_public_subnets"></a> [vpc\_public\_subnets](#output\_vpc\_public\_subnets) | The newly created vpc public subnets IDs list |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
