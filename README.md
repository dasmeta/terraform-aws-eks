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
- karpenter
- keda
- linkerd
- flagger
- external-dns
- event-exporter

## Upgrading guide:
 - from <2.19.0 to >=2.19.0 version needs some manual actions as we upgraded underlying eks module from 18.x.x to 20.x.x,
   here you can find needed actions/changes docs and ready scripts which can be used:
   docs:
     https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-19.0.md
     https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/UPGRADE-20.0.md
   params:
     The node group create\_launch\_template=false and launch\_template\_name="" pair params have been replaced with use\_custom\_launch\_template=false
   scripts:
   ```sh
    # commands to move some states, run before applying the `terraform apply` for new version
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.kubernetes_config_map_v1_data.aws_auth[0]" "module.<eks-module-name>.module.eks-cluster[0].module.aws_auth_config_map.kubernetes_config_map_v1_data.aws_auth[0]"
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_9443_webhook\"]"
    terraform state mv "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443\"]" "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_security_group_rule.node[\"ingress_cluster_8443_webhook\"]"
    # command to run in case upgrading from <2.14.6 version, run before applying the `terraform apply` for new version
    terraform state rm "module.<eks-module-name>.module.autoscaler[0].aws_iam_policy.policy"
    # command to run when apply fails to create the existing resource "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
    terraform import "module.<eks-module-name>.module.eks-cluster[0].module.eks-cluster.aws_eks_access_entry.this[\"cluster_creator\"]" "<eks-cluster-name>:arn:aws:iam::<aws-account-id>:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_AdministratorAccess_<some-hash>"
    # command to apply when secret store fails to be linked, probably there will be need to remove the resource
    terraform import "module.secret_store.kubectl_manifest.main" external-secrets.io/v1beta1//SecretStore//app-test//default
   ```
 - from <2.20.0 to >=2.20.0 version
   - in case if karpenter is enabled.
     the karpenter chart have been upgraded and CRDs creation have been moved into separate chart and there is need to run following kubectl commands before applying module update:
     ```bash
     kubectl patch crd ec2nodeclasses.karpenter.k8s.aws -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     kubectl patch crd nodeclaims.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     kubectl patch crd nodepools.karpenter.sh -p '{"metadata":{"labels":{"app.kubernetes.io/managed-by":"Helm"},"annotations":{"meta.helm.sh/release-name":"karpenter-crd","meta.helm.sh/release-namespace":"karpenter"}}}'
     ```
   - the alb ingress/load-balancer controller variables have been moved under one variable set `alb_load_balancer_controller` so you have to change old way passed config(if you have this variables manually passed), here is the moved ones: `enable_alb_ingress_controller`, `enable_waf_for_alb`, `alb_log_bucket_name`, `alb_log_bucket_path`, `send_alb_logs_to_cloudwatch`
 - from <2.30.0 to >=2.30.0 version
   - this version upgrade brings about all underlying main components updated to latest versions and eks default version 1.30. all core/important components compatibility have been tested with install from scratch and when applying the update over old version, but in any case possibility of issues in custom configured setups. so that make sure you apply the update in dev/stage environments at first and test that all works as expected and then apply for prod/live.
   - in case if karpenter is enabled there is some tricky behavior while upgrade.
     the karpenter managed spot instances got interrupted more often(this seems related karpenter drift ability and k8s version+ami version update, so that 2 separate waves of change arrive) so that at some upgrade point there even we can have case without any karpenter managed instance(still needs deeper investigation). So make sure:
       - to apply the upgrade at the time when no much traffic to website and if possible cool down critical service which have to not be restarted.
       - make sure to set PDB on workloads, which will allow to prevent all workload pods be unavailable at certain point.
       - also in case if you have pods with annotations `karpenter.sh/do-not-disrupt: "true"` you may be have need to manually disrupt this pods in order to get their karpenter managed nodes be disrupted/recreated as well to get the new eks version. you can use this annotation to also to prevent karpenter to disrupt nodes where we have such pods, this is handy to manually control when an node can be disrupted.
   - the default addon coredns have explicitly set default configurations, and this configs available to configure via var.default\_addons config. if you have manually set configs for coredns that differ from default ones here in the module then you may need to set/change the coredns configs in module use to not get your custom ones overridden and missing.

## How to run
```hcl
data "aws_availability_zones" "available" {}

locals {
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
}

#(Basic usage with example of using already created VPC)
data "aws_availability_zones" "available" {}

locals {
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
}

# Minimum

module "cluster_min" {
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

}

# Max @TODO: the max param passing setup needs to be checked/fixed

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
   root_volume_type                = "gp3"
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
}
```

## karpenter enabled
### NOTES:
###  - enabling karpenter automatically disables cluster auto-scaler, starting from 2.30.0 version karpenter is enabled by default
###  - if vpc have been created externally(not inside this module) then you may need to set the following tags on private subnets `karpenter.sh/discovery=<cluster-name>`
###  - then enabling karpenter on existing old cluster there is possibility to see cycle-dependency error, to overcome this you need at first to apply main eks module change (`terraform apply --target "module.<eks-module-name>.module.eks-cluster"`) and then rest of cluster-autoloader destroy and karpenter install ones
###  - when destroying cluster which have karpenter enabled there is possibility of failure on karpenter resource removal, you need to run destruction one more time to get it complete
###  - in order to be able to use spot instances you may need to create AWSServiceRoleForEC2Spot IAM role on aws account(TODO: check and create this role on account module automatically), here is the doc: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/service-linked-roles-spot-instance-requests.html , otherwise karpenter created `nodeclaim` kubernetes resource will show AuthFailure.ServiceLinkedRoleCreationNotPermitted error
###  - karpenter is designed to keep nodes as cheep as possible to that by default it can dynamically disrupt/collocate nodes, even on-demand ones. So in order to control the process in specific cases use following options: setting `karpenter.sh/do-not-disrupt: "true"` for pod (or this can be set also on node) prevents karpenter to disrupt the node where pod runs(be aware to manually drain such nodes when you do eks version upgrades), also pods PDB(PodDisruptionBudget) option can be used as karpenter respects this, the node-pools disruption params also can be used to create more advanced logics(my default `disruption = { consolidationPolicy="WhenEmptyOrUnderutilized", consolidateAfter="3m", budgets={nodes : "10%"}}`)

```terraform
module "eks" {
 source  = "dasmeta/eks/aws"
 version = "3.x.x"
 .....
 karpenter = {
  enabled = true
  configs = {
    replicas = 1
  }
  resource_configs_defaults = { # this is optional param, look into karpenter submodule to get available defaults
    limits = {
      cpu = 11 # the default is 10 and we can add limit restrictions on memory also
    }
  }
  resource_configs = {
    nodePools = {
      general = { weight = 1 } # by default it use linux amd64 cpu<6, memory<10000Mi, >2 generation and  ["spot", "on-demand"] type nodes so that it tries to get spot at first and if no then on-demand
    }
  }
 }
 .....
}
```
**/

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.31, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.4.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~>1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.31, < 6.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.4.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_adot"></a> [adot](#module\_adot) | ./modules/adot | n/a |
| <a name="module_alb-ingress-controller"></a> [alb-ingress-controller](#module\_alb-ingress-controller) | ./modules/aws-load-balancer-controller | n/a |
| <a name="module_api-gw-controller"></a> [api-gw-controller](#module\_api-gw-controller) | ./modules/api-gw | n/a |
| <a name="module_autoscaler"></a> [autoscaler](#module\_autoscaler) | ./modules/autoscaler | n/a |
| <a name="module_cloudwatch-metrics"></a> [cloudwatch-metrics](#module\_cloudwatch-metrics) | ./modules/cloudwatch-metrics | n/a |
| <a name="module_cw_alerts"></a> [cw\_alerts](#module\_cw\_alerts) | dasmeta/monitoring/aws//modules/alerts | 1.3.5 |
| <a name="module_ebs-csi"></a> [ebs-csi](#module\_ebs-csi) | ./modules/ebs-csi | n/a |
| <a name="module_efs-csi-driver"></a> [efs-csi-driver](#module\_efs-csi-driver) | ./modules/efs-csi | n/a |
| <a name="module_eks-cluster"></a> [eks-cluster](#module\_eks-cluster) | ./modules/eks | n/a |
| <a name="module_eks-core-components"></a> [eks-core-components](#module\_eks-core-components) | dasmeta/empty/null | 1.2.2 |
| <a name="module_eks-core-components-and-alb"></a> [eks-core-components-and-alb](#module\_eks-core-components-and-alb) | dasmeta/empty/null | 1.2.2 |
| <a name="module_event_exporter"></a> [event\_exporter](#module\_event\_exporter) | ./modules/event-exporter | n/a |
| <a name="module_external-dns"></a> [external-dns](#module\_external-dns) | ./modules/external-dns | n/a |
| <a name="module_external-secrets"></a> [external-secrets](#module\_external-secrets) | ./modules/external-secrets | n/a |
| <a name="module_flagger"></a> [flagger](#module\_flagger) | ./modules/flagger | n/a |
| <a name="module_fluent-bit"></a> [fluent-bit](#module\_fluent-bit) | ./modules/fluent-bit | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | ./modules/karpenter | n/a |
| <a name="module_keda"></a> [keda](#module\_keda) | ./modules/keda | n/a |
| <a name="module_linkerd"></a> [linkerd](#module\_linkerd) | ./modules/linkerd | n/a |
| <a name="module_metrics-server"></a> [metrics-server](#module\_metrics-server) | ./modules/metrics-server | n/a |
| <a name="module_namespaces_and_docker_auth"></a> [namespaces\_and\_docker\_auth](#module\_namespaces\_and\_docker\_auth) | ./modules/namespaces-and-docker-auth | n/a |
| <a name="module_nginx-ingress-controller"></a> [nginx-ingress-controller](#module\_nginx-ingress-controller) | ./modules/nginx-ingress-controller/ | n/a |
| <a name="module_node-problem-detector"></a> [node-problem-detector](#module\_node-problem-detector) | ./modules/node-problem-detector | n/a |
| <a name="module_olm"></a> [olm](#module\_olm) | ./modules/olm | n/a |
| <a name="module_portainer"></a> [portainer](#module\_portainer) | ./modules/portainer | n/a |
| <a name="module_priority_class"></a> [priority\_class](#module\_priority\_class) | ./modules/priority-class/ | n/a |
| <a name="module_s3-csi"></a> [s3-csi](#module\_s3-csi) | ./modules/s3-csi | n/a |
| <a name="module_sso-rbac"></a> [sso-rbac](#module\_sso-rbac) | ./modules/sso-rbac | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | dasmeta/vpc/aws | 1.0.1 |
| <a name="module_weave-scope"></a> [weave-scope](#module\_weave-scope) | ./modules/weave-scope | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.cert-manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.kube-state-metrics](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.meta-system](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account Id to apply changes into | `string` | `null` | no |
| <a name="input_additional_priority_classes"></a> [additional\_priority\_classes](#input\_additional\_priority\_classes) | Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high'(1000000), 'medium'(500000) and 'low'(250000) . You can also provide a custom list of Priority Classes if needed. | <pre>list(object({<br/>    name  = string<br/>    value = string # number in string form<br/>  }))</pre> | `[]` | no |
| <a name="input_adot_config"></a> [adot\_config](#input\_adot\_config) | accept\_namespace\_regex defines the list of namespaces from which metrics will be exported, and additional\_metrics defines additional metrics to export. | <pre>object({<br/>    accept_namespace_regex = optional(string, "(default|kube-system)")<br/>    additional_metrics     = optional(list(string), [])<br/>    log_group_name         = optional(string, "adot")<br/>    log_retention          = optional(number, 14)<br/>    helm_values            = optional(any, null)<br/>    logging_enable         = optional(bool, false)<br/>    resources = optional(object({<br/>      limit = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      requests = object({<br/>        cpu    = optional(string, "200m")<br/>        memory = optional(string, "200Mi")<br/>      })<br/>      }), {<br/>      limit = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>      }<br/>      requests = {<br/>        cpu    = "200m"<br/>        memory = "200Mi"<br/>      }<br/>    })<br/>  })</pre> | <pre>{<br/>  "accept_namespace_regex": "(default|kube-system)",<br/>  "additional_metrics": [],<br/>  "helm_values": null,<br/>  "log_group_name": "adot",<br/>  "log_retention": 14,<br/>  "logging_enable": false,<br/>  "resources": {<br/>    "limit": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    },<br/>    "requests": {<br/>      "cpu": "200m",<br/>      "memory": "200Mi"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_adot_version"></a> [adot\_version](#input\_adot\_version) | The version of the AWS Distro for OpenTelemetry addon to use. If not passed it will get compatible version based on cluster\_version | `string` | `null` | no |
| <a name="input_alarms"></a> [alarms](#input\_alarms) | Alarms enabled by default you need set sns topic name for send alarms for customize alarms threshold use custom\_values | <pre>object({<br/>    enabled       = optional(bool, true)<br/>    sns_topic     = string<br/>    custom_values = optional(any, {})<br/>  })</pre> | n/a | yes |
| <a name="input_alb_load_balancer_controller"></a> [alb\_load\_balancer\_controller](#input\_alb\_load\_balancer\_controller) | Aws alb ingress/load-balancer controller configs. | <pre>object({<br/>    enabled                     = optional(bool, true)  # Whether alb ingress/load-balancer controller enabled, note that alb load balancer will be created also when nginx_ingress_controller_config.enabled=true as nginx loadbalancer service needs it<br/>    enable_waf_for_alb          = optional(bool, false) # Enables WAF and WAF V2 addons for ALB<br/>    configs                     = optional(any, {})     # allows to pass additional helm chart configs<br/>    alb_log_bucket_name         = optional(string, "")  # The s3 bucket where alb logs will be placed, TODO: option and its related ability disable, check if we need this ability<br/>    alb_log_bucket_path         = optional(string, "")  # The s3 bucket path/folder where alb logs will be placed, TODO: option and its related ability disable, check if we need this ability<br/>    send_alb_logs_to_cloudwatch = optional(bool, true)  # Whether logs will be pushed to cloudwatch also, TODO: option and its related ability disable, check if we need this ability<br/>  })</pre> | `{}` | no |
| <a name="input_api_gateway_resources"></a> [api\_gateway\_resources](#input\_api\_gateway\_resources) | Nested map containing API, Stage, and VPC Link resources | <pre>list(object({<br/>    namespace = string<br/>    api = object({<br/>      name         = string<br/>      protocolType = string<br/>    })<br/>    stages = optional(list(object({<br/>      name        = string<br/>      namespace   = string<br/>      apiRef_name = string<br/>      stageName   = string<br/>      autoDeploy  = bool<br/>      description = string<br/>    })))<br/>    vpc_links = optional(list(object({<br/>      name      = string<br/>      namespace = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_api_gw_deploy_region"></a> [api\_gw\_deploy\_region](#input\_api\_gw\_deploy\_region) | Region in which API gatewat will be configured | `string` | `""` | no |
| <a name="input_autoscaler_image_patch"></a> [autoscaler\_image\_patch](#input\_autoscaler\_image\_patch) | The patch number of autoscaler image | `number` | `0` | no |
| <a name="input_autoscaler_limits"></a> [autoscaler\_limits](#input\_autoscaler\_limits) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_autoscaler_requests"></a> [autoscaler\_requests](#input\_autoscaler\_requests) | n/a | <pre>object({<br/>    cpu    = string<br/>    memory = string<br/>  })</pre> | <pre>{<br/>  "cpu": "100m",<br/>  "memory": "600Mi"<br/>}</pre> | no |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | Weather enable cluster autoscaler for EKS, in case if karpenter enabled this config will be ignored and the cluster autoscaler will be considered as disabled | `bool` | `true` | no |
| <a name="input_bindings"></a> [bindings](#input\_bindings) | Variable which describes group and role binding | <pre>list(object({<br/>    group     = string<br/>    namespace = string<br/>    roles     = list(string)<br/><br/>  }))</pre> | `[]` | no |
| <a name="input_cert_manager_chart_version"></a> [cert\_manager\_chart\_version](#input\_cert\_manager\_chart\_version) | The cert-manager helm chart version. | `string` | `"1.16.2"` | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | Cluster addon configurations to enable. | `any` | `{}` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html) | `list(string)` | `[]` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | n/a | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Creating eks cluster name. | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Allows to set/change kubernetes cluster version, kubernetes version needs to be updated at leas once a year. Please check here for available versions https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html | `string` | `"1.30"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create cluster and other resources or not | `bool` | `true` | no |
| <a name="input_create_cert_manager"></a> [create\_cert\_manager](#input\_create\_cert\_manager) | If enabled it always gets deployed to the cert-manager namespace. | `bool` | `false` | no |
| <a name="input_default_addons"></a> [default\_addons](#input\_default\_addons) | Allows to set/override default eks addons(like coredns, kube-proxy and aws-cni) configurations. | `any` | <pre>{<br/>  "coredns": {<br/>    "configuration_values": {<br/>      "corefile": "        .:53 {\n            errors\n            health {\n                lameduck 5s\n              }\n            ready\n            kubernetes cluster.local in-addr.arpa ip6.arpa {\n              pods insecure\n              fallthrough in-addr.arpa ip6.arpa\n              ttl 120\n            }\n            prometheus :9153\n            forward . /etc/resolv.conf {\n              max_concurrent 2000\n            }\n            cache 30\n            loop\n            reload\n            loadbalance\n        }\n",<br/>      "replicaCount": 2,<br/>      "resources": {<br/>        "limits": {<br/>          "memory": "171Mi"<br/>        },<br/>        "requests": {<br/>          "cpu": "100m",<br/>          "memory": "70Mi"<br/>        }<br/>      }<br/>    },<br/>    "most_recent": true<br/>  }<br/>}</pre> | no |
| <a name="input_ebs_csi_version"></a> [ebs\_csi\_version](#input\_ebs\_csi\_version) | EBS CSI driver addon version, by default it will pick right version for this driver based on cluster\_version | `string` | `null` | no |
| <a name="input_efs_id"></a> [efs\_id](#input\_efs\_id) | EFS filesystem id in AWS | `string` | `null` | no |
| <a name="input_efs_storage_classes"></a> [efs\_storage\_classes](#input\_efs\_storage\_classes) | Additional storage class configurations: by default, 2 storage classes are created - efs-sc and efs-sc-root which has 0 uid. One can add another storage classes besides these 2. | <pre>list(object({<br/>    name : string<br/>    provisioning_mode : optional(string, "efs-ap")<br/>    file_system_id : string<br/>    directory_perms : optional(string, "755")<br/>    base_path : optional(string, "/")<br/>    uid : optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_enable_api_gw_controller"></a> [enable\_api\_gw\_controller](#input\_enable\_api\_gw\_controller) | Weather enable API-GW controller or not | `bool` | `false` | no |
| <a name="input_enable_ebs_driver"></a> [enable\_ebs\_driver](#input\_enable\_ebs\_driver) | Weather enable EBS-CSI driver or not | `bool` | `true` | no |
| <a name="input_enable_efs_driver"></a> [enable\_efs\_driver](#input\_enable\_efs\_driver) | Weather install EFS driver or not in EKS | `bool` | `false` | no |
| <a name="input_enable_external_secrets"></a> [enable\_external\_secrets](#input\_enable\_external\_secrets) | Whether to enable external-secrets operator | `bool` | `true` | no |
| <a name="input_enable_kube_state_metrics"></a> [enable\_kube\_state\_metrics](#input\_enable\_kube\_state\_metrics) | Enable kube-state-metrics | `bool` | `false` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | METRICS-SERVER | `bool` | `false` | no |
| <a name="input_enable_node_problem_detector"></a> [enable\_node\_problem\_detector](#input\_enable\_node\_problem\_detector) | n/a | `bool` | `true` | no |
| <a name="input_enable_olm"></a> [enable\_olm](#input\_enable\_olm) | To install OLM controller (experimental). | `bool` | `false` | no |
| <a name="input_enable_portainer"></a> [enable\_portainer](#input\_enable\_portainer) | Enable Portainer provisioning or not | `bool` | `false` | no |
| <a name="input_enable_sso_rbac"></a> [enable\_sso\_rbac](#input\_enable\_sso\_rbac) | Enable SSO RBAC integration or not | `bool` | `false` | no |
| <a name="input_event_exporter"></a> [event\_exporter](#input\_event\_exporter) | Allows to create/configure event\_exporter in eks cluster. The configs option is object to pass corresponding to preferred helm values.yaml, for more details check: https://artifacthub.io/packages/helm/bitnami/kubernetes-event-exporter?modal=values | <pre>object({<br/>    enabled = optional(bool, false)<br/>    configs = optional(any, {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_external_dns"></a> [external\_dns](#input\_external\_dns) | Allows to install external-dns helm chart and related roles, which allows to automatically create R53 records based on ingress/service domain/host configs | <pre>object({<br/>    enabled = optional(bool, false)<br/>    configs = optional(any, {})<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_external_secrets_namespace"></a> [external\_secrets\_namespace](#input\_external\_secrets\_namespace) | The namespace of external-secret operator | `string` | `"kube-system"` | no |
| <a name="input_flagger"></a> [flagger](#input\_flagger) | Allows to create/deploy flagger operator to have custom rollout strategies like canary/blue-green and also it allows to create custom flagger metric templates | <pre>object({<br/>    enabled                    = optional(bool, false)<br/>    namespace                  = optional(string, "ingress-nginx") # The flagger operator helm being installed on same namespace as mesh/ingress provider so this field need to be set based on which ingress/mesh we are going to use, more info in https://artifacthub.io/packages/helm/flagger/flagger<br/>    configs                    = optional(any, {})                 # Available options can be found in https://artifacthub.io/packages/helm/flagger/flagger<br/>    metrics_and_alerts_configs = optional(any, {})                 # Available options can be found in https://github.com/dasmeta/helm/tree/flagger-metrics-and-alerts-0.1.0/charts/flagger-metrics-and-alerts<br/>    enable_loadtester          = optional(bool, false)             # Whether to install flagger loadtester helm<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_fluent_bit_configs"></a> [fluent\_bit\_configs](#input\_fluent\_bit\_configs) | Fluent Bit configs | <pre>object({<br/>    enabled               = optional(string, true)<br/>    fluent_bit_name       = optional(string, "")<br/>    log_group_name        = optional(string, "")<br/>    system_log_group_name = optional(string, "")<br/>    log_retention_days    = optional(number, 90)<br/>    values_yaml           = optional(string, "")<br/>    configs = optional(object({<br/>      inputs                     = optional(string, "")<br/>      filters                    = optional(string, "")<br/>      outputs                    = optional(string, "")<br/>      cloudwatch_outputs_enabled = optional(bool, true)<br/>    }), {})<br/>    drop_namespaces        = optional(list(string), [])<br/>    log_filters            = optional(list(string), [])<br/>    additional_log_filters = optional(list(string), [])<br/>    kube_namespaces        = optional(list(string), [])<br/>    image_pull_secrets     = optional(list(string), [])<br/>  })</pre> | <pre>{<br/>  "additional_log_filters": [<br/>    "ELB-HealthChecker",<br/>    "Amazon-Route53-Health-Check-Service"<br/>  ],<br/>  "configs": {<br/>    "cloudwatch_outputs_enabled": true,<br/>    "filters": "",<br/>    "inputs": "",<br/>    "outputs": ""<br/>  },<br/>  "drop_namespaces": [<br/>    "kube-system",<br/>    "opentelemetry-operator-system",<br/>    "adot",<br/>    "cert-manager",<br/>    "opentelemetry.*",<br/>    "meta.*"<br/>  ],<br/>  "enabled": true,<br/>  "fluent_bit_name": "",<br/>  "image_pull_secrets": [],<br/>  "kube_namespaces": [<br/>    "kube.*",<br/>    "meta.*",<br/>    "adot.*",<br/>    "devops.*",<br/>    "cert-manager.*",<br/>    "git.*",<br/>    "opentelemetry.*",<br/>    "stakater.*",<br/>    "renovate.*"<br/>  ],<br/>  "log_filters": [<br/>    "kube-probe",<br/>    "health",<br/>    "prometheus",<br/>    "liveness"<br/>  ],<br/>  "log_group_name": "",<br/>  "log_retention_days": 90,<br/>  "system_log_group_name": "",<br/>  "values_yaml": ""<br/>}</pre> | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Allows to create/deploy/configure karpenter operator and its resources to have custom node auto-calling | <pre>object({<br/>    enabled                   = optional(bool, true)<br/>    configs                   = optional(any, {})                               # karpenter chart configs, the underlying module sets some general/default ones, available option can be found here: https://github.com/aws/karpenter-provider-aws/blob/v1.0.8/charts/karpenter/values.yaml<br/>    resource_configs          = optional(any, { nodePools = { general = {} } }) # karpenter resources creation configs, available options can be fount here: https://github.com/dasmeta/helm/tree/karpenter-resources-0.1.0/charts/karpenter-resources<br/>    resource_configs_defaults = optional(any, {})                               # the default used for karpenter node pool creation, the available values to override/set can be found in karpenter submodule corresponding variable modules/karpenter/values.tf<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_keda"></a> [keda](#input\_keda) | Allows to create/deploy/configure keda | <pre>object({<br/>    enabled          = optional(bool, true)<br/>    name             = optional(string, "keda")   # keda chart name,<br/>    namespace        = optional(string, "keda")   # keda chart namespace<br/>    create_namespace = optional(bool, true)       # create keda chart<br/>    keda_version     = optional(string, "2.16.1") # chart version<br/>    attach_policies = optional(object({<br/>      sqs = bool<br/>    }), { sqs = false })<br/>    keda_trigger_auth_additional = optional(any, null)<br/>  })</pre> | <pre>{<br/>  "create_namespace": true,<br/>  "enabled": true,<br/>  "keda_version": "2.16.1",<br/>  "name": "keda",<br/>  "namespace": "keda"<br/>}</pre> | no |
| <a name="input_kube_state_metrics_chart_version"></a> [kube\_state\_metrics\_chart\_version](#input\_kube\_state\_metrics\_chart\_version) | The kube-state-metrics chart version | `string` | `"5.27.0"` | no |
| <a name="input_linkerd"></a> [linkerd](#input\_linkerd) | Allows to create/configure linkerd in eks cluster | <pre>object({<br/>    enabled     = optional(bool, true)<br/>    configs     = optional(any, {})    # allows to override default configs of linkerd main helm chart, check underlying sub-module module for more info<br/>    configs_viz = optional(any, {})    # allows to override default configs of linkerd viz helm chart, check underlying sub-module module for more info<br/>    crds_create = optional(bool, true) # whether to have linkerd crd installed<br/>    viz_create  = optional(bool, true) # whether to have linkerd monitoring/dashboard tooling installed<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_manage_aws_auth"></a> [manage\_aws\_auth](#input\_manage\_aws\_auth) | n/a | `bool` | `true` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | Additional IAM roles to add to the aws-auth configmap. | <pre>list(object({<br/>    rolearn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_metrics_exporter"></a> [metrics\_exporter](#input\_metrics\_exporter) | Metrics Exporter, can use cloudwatch or adot | `string` | `"adot"` | no |
| <a name="input_metrics_server_name"></a> [metrics\_server\_name](#input\_metrics\_server\_name) | n/a | `string` | `"metrics-server"` | no |
| <a name="input_namespaces_and_docker_auth"></a> [namespaces\_and\_docker\_auth](#input\_namespaces\_and\_docker\_auth) | Allows to create application namespaces, like 'prod' or 'dev' automatically. it can also set to use docker hub credential for image pull | <pre>object({<br/>    enabled = optional(bool, false)<br/>    list    = optional(list(string), []) # list of application namespaces to create/init with cluster creation<br/>    labels  = optional(any, {})          # map of key=>value strings to attach to namespaces<br/>    dockerAuth = optional(object({       # docker hub image registry configs, this based external secrets operator(operator should be enabled). which will allow to create 'kubernetes.io/dockerconfigjson' type secrets in app(and also all other) namespaces and configure app namespaces to use this<br/>      enabled                 = optional(bool, false)<br/>      refreshTime             = optional(string, "3m")                                         # frequency to check filtered namespaces and create ExternalSecrets (and k8s secret)<br/>      refreshInterval         = optional(string, "1h")                                         # frequency to pull/refresh data from aws secret<br/>      name                    = optional(string, "docker-registry-auth")                       # the name to use when creating k8s resources<br/>      secretManagerSecretName = optional(string, "account")                                    # aws secret manager secret name where dockerhub credentials placed, we use "account" default secret<br/>      namespaceSelector       = optional(any, { matchLabels : { "docker-auth" = "enabled" } }) # namespaces selector expression, the app namespaces created here will have this selectors by default, but for other namespaces you may need to set labels manually. this can be set to empty object {} to create secrets in all namespaces<br/>      registries = optional(list(object({                                                      # docker registry configs<br/>        url         = optional(string, "https://index.docker.io/v1/")                          # docker registry server url<br/>        usernameKey = optional(string, "DOCKER_HUB_USERNAME")                                  # the aws secret manager secret key where docker registry username placed<br/>        passwordKey = optional(string, "DOCKER_HUB_PASSWORD")                                  # the aws secret manager secret key where docker registry password placed, NOTE: for dockerhub under this key should be set personal access token instead of standard ui/profile password<br/>        authKey     = optional(string)                                                         # the aws secret manager secret key where docker registry auth placed<br/>      })), [{ url = "https://index.docker.io/v1/", usernameKey = "DOCKER_HUB_USERNAME", passwordKey = "DOCKER_HUB_PASSWORD", authKey = null }])<br/>    }), { enabled = false })<br/>  })</pre> | `{}` | no |
| <a name="input_nginx_ingress_controller_config"></a> [nginx\_ingress\_controller\_config](#input\_nginx\_ingress\_controller\_config) | Nginx ingress controller configs | <pre>object({<br/>    enabled          = optional(bool, false)<br/>    name             = optional(string, "nginx")<br/>    create_namespace = optional(bool, true)<br/>    namespace        = optional(string, "ingress-nginx")<br/>    replicacount     = optional(number, 3)<br/>    metrics_enabled  = optional(bool, true)<br/>    configs          = optional(any, {}) # Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.12.0?modal=values<br/>  })</pre> | <pre>{<br/>  "create_namespace": true,<br/>  "enabled": false,<br/>  "metrics_enabled": true,<br/>  "name": "nginx",<br/>  "namespace": "ingress-nginx",<br/>  "replicacount": 3<br/>}</pre> | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node group definitions to create | `any` | <pre>{<br/>  "default": {<br/>    "desired_size": 2,<br/>    "iam_role_additional_policies": {<br/>      "CloudWatchAgentServerPolicy": "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br/>    },<br/>    "instance_types": [<br/>      "t3.large"<br/>    ],<br/>    "max_size": 4,<br/>    "min_size": 2<br/>  }<br/>}</pre> | no |
| <a name="input_node_groups_default"></a> [node\_groups\_default](#input\_node\_groups\_default) | Map of EKS managed node group default configurations | `any` | <pre>{<br/>  "disk_size": 50,<br/>  "iam_role_additional_policies": {<br/>    "CloudWatchAgentServerPolicy": "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"<br/>  },<br/>  "instance_types": [<br/>    "t3.large"<br/>  ]<br/>}</pre> | no |
| <a name="input_node_security_group_additional_rules"></a> [node\_security\_group\_additional\_rules](#input\_node\_security\_group\_additional\_rules) | n/a | `any` | <pre>{<br/>  "ingress_cluster_10250": {<br/>    "description": "Metric server to node groups",<br/>    "from_port": 10250,<br/>    "protocol": "tcp",<br/>    "self": true,<br/>    "to_port": 10250,<br/>    "type": "ingress"<br/>  }<br/>}</pre> | no |
| <a name="input_portainer_config"></a> [portainer\_config](#input\_portainer\_config) | Portainer hostname and ingress config. | <pre>object({<br/>    host           = optional(string, "portainer.dasmeta.com")<br/>    enable_ingress = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_prometheus_metrics"></a> [prometheus\_metrics](#input\_prometheus\_metrics) | Prometheus Metrics | `any` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region name. | `string` | `null` | no |
| <a name="input_roles"></a> [roles](#input\_roles) | Variable describes which role will user have K8s | <pre>list(object({<br/>    actions   = list(string)<br/>    resources = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_s3_csi"></a> [s3\_csi](#input\_s3\_csi) | S3 CSI driver addon version, by default it will pick right version for this driver based on cluster\_version | <pre>object({<br/>    enabled       = optional(bool, false)<br/>    addon_version = optional(string, null)     # if not passed it will use latest compatible version<br/>    buckets       = optional(list(string), []) # the name of buckets to create policy to be able to mount them to containers, if not specified it uses all/*<br/>  })</pre> | `{}` | no |
| <a name="input_scale_down_unneeded_time"></a> [scale\_down\_unneeded\_time](#input\_scale\_down\_unneeded\_time) | Scale down unneeded in minutes | `number` | `2` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Extra tags to attach to eks cluster. | `any` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to open eks cluster api access | `list(any)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration for eks, we support both cases create new vpc(create field) and using already created one(link) | <pre>object({<br/>    # for linking using existing vpc<br/>    link = optional(object({<br/>      id                 = string<br/>      private_subnet_ids = list(string) # please have the existing vpc public/private subnets(at least 2 needed) tagged with corresponding tags(look into create case subnet tags defaults)<br/>    }), { id = null, private_subnet_ids = null })<br/>    # for creating new vpc<br/>    create = optional(object({<br/>      name                = string<br/>      availability_zones  = list(string)<br/>      cidr                = string<br/>      private_subnets     = list(string)<br/>      public_subnets      = list(string)<br/>      public_subnet_tags  = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/elb" = 1}<br/>      private_subnet_tags = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/internal-elb" = 1}<br/>    }), { name = null, availability_zones = null, cidr = null, private_subnets = null, public_subnets = null })<br/>  })</pre> | n/a | yes |
| <a name="input_weave_scope_config"></a> [weave\_scope\_config](#input\_weave\_scope\_config) | Weave scope namespace configuration variables | <pre>object({<br/>    create_namespace        = bool<br/>    namespace               = string<br/>    annotations             = map(string)<br/>    ingress_host            = string<br/>    ingress_class           = string<br/>    ingress_name            = string<br/>    service_type            = string<br/>    weave_helm_release_name = string<br/>  })</pre> | <pre>{<br/>  "annotations": {},<br/>  "create_namespace": true,<br/>  "ingress_class": "",<br/>  "ingress_host": "",<br/>  "ingress_name": "weave-ingress",<br/>  "namespace": "meta-system",<br/>  "service_type": "NodePort",<br/>  "weave_helm_release_name": "weave"<br/>}</pre> | no |
| <a name="input_weave_scope_enabled"></a> [weave\_scope\_enabled](#input\_weave\_scope\_enabled) | Weather enable Weave Scope or not | `bool` | `false` | no |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | Worker groups. | `any` | `{}` | no |
| <a name="input_workers_group_defaults"></a> [workers\_group\_defaults](#input\_workers\_group\_defaults) | Worker group defaults. | `any` | <pre>{<br/>  "launch_template_name": "default",<br/>  "launch_template_use_name_prefix": true,<br/>  "root_volume_size": 50,<br/>  "root_volume_type": "gp3"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | n/a |
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
| <a name="output_external_secret_deployment"></a> [external\_secret\_deployment](#output\_external\_secret\_deployment) | n/a |
| <a name="output_map_user_data"></a> [map\_user\_data](#output\_map\_user\_data) | n/a |
| <a name="output_namespaces_and_docker_auth_helm_metadata"></a> [namespaces\_and\_docker\_auth\_helm\_metadata](#output\_namespaces\_and\_docker\_auth\_helm\_metadata) | n/a |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ## CLUSTER |
| <a name="output_region"></a> [region](#output\_region) | n/a |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | n/a |
| <a name="output_role_arns_without_path"></a> [role\_arns\_without\_path](#output\_role\_arns\_without\_path) | n/a |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The cidr block of the vpc |
| <a name="output_vpc_default_security_group_id"></a> [vpc\_default\_security\_group\_id](#output\_vpc\_default\_security\_group\_id) | The ID of default security group created for vpc |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The newly created vpc id |
| <a name="output_vpc_nat_public_ips"></a> [vpc\_nat\_public\_ips](#output\_vpc\_nat\_public\_ips) | The list of elastic public IPs for vpc |
| <a name="output_vpc_private_subnets"></a> [vpc\_private\_subnets](#output\_vpc\_private\_subnets) | The newly created vpc private subnets IDs list |
| <a name="output_vpc_public_subnets"></a> [vpc\_public\_subnets](#output\_vpc\_public\_subnets) | The newly created vpc public subnets IDs list |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
