# VPC
variable "vpc_name" {
  type        = string
  description = "Creating VPC name."
}

variable "cidr" {
  type = string
  # default = "172.16.0.0/16"
  description = "CIDR ip range."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of VPC availability zones, e.g. ['eu-west-1a', 'eu-west-1b', 'eu-west-1c']."
}

variable "private_subnets" {
  type = list(string)
  # default = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  description = "Private subnets of VPC."
}

variable "public_subnets" {
  type = list(string)
  # default = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  description = "Public subnets of VPC."
}

variable "public_subnet_tags" {
  type    = map(any)
  default = {}
}

variable "private_subnet_tags" {
  type    = map(any)
  default = {}
}

#EKS
variable "cluster_name" {
  type        = string
  description = "Creating eks cluster name."
}

variable "manage_aws_auth" {
  type    = bool
  default = true
}

variable "worker_groups" {
  type        = any
  default     = {}
  description = "Worker groups."
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default = {
    default = {
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.medium"]
    }
  }
}

variable "node_security_group_additional_rules" {
  type = any
  default = {
    ingress_cluster_8443 = {
      description                   = "Metric server to node groups"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    },
  }
}

variable "node_groups_default" {
  description = "Map of EKS managed node group default configurations"
  type        = any
  default = {
    disk_size      = 50
    instance_types = ["t3.medium"]
  }
}

variable "workers_group_defaults" {
  type = any

  default = {
    launch_template_use_name_prefix = true
    launch_template_name            = "default"
    root_volume_type                = "gp2"
    root_volume_size                = 50
  }
  description = "Worker group defaults."
}

variable "users" {
  type = any
}

# ALB-INGRESS-CONTROLLER
variable "alb_log_bucket_path" {
  type    = string
  default = ""
}

variable "alb_log_bucket_name" {
  type    = string
  default = ""
}

# FLUENT-BIT
variable "fluent_bit_name" {
  type    = string
  default = ""
}

variable "log_group_name" {
  type    = string
  default = ""
}

# METRICS-SERVER
variable "enable_metrics_server" {
  type    = bool
  default = false
}

variable "metrics_server_name" {
  type    = string
  default = "metrics-server"
}
variable "cluster_endpoint_public_access" {
  type    = bool
  default = true
}

variable "external_secrets_namespace" {
  type        = string
  description = "The namespace of external-secret operator"
  default     = "kube-system"
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  type        = list(string)
  default     = ["audit"]
}

variable "cluster_version" {
  description = "Allows to set/change kubernetes cluster version, kubernetes version needs to be updated at leas once a year. Please check here for available versions https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
  type        = string
  default     = "1.22"
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "weave_scope_config" {
  description = "Weave scope namespace configuration variables"
  type = object({
    create_namespace        = bool
    namespace               = string
    annotations             = map(string)
    ingress_host            = string
    ingress_class           = string
    ingress_name            = string
    service_type            = string
    weave_helm_release_name = string
  })
  default = {
    create_namespace        = true
    namespace               = "meta-system"
    annotations             = {}
    ingress_host            = ""
    ingress_class           = ""
    service_type            = "NodePort"
    weave_helm_release_name = "weave"
    ingress_name            = "weave-ingress"
  }
}

variable "weave_scope_enabled" {
  description = "Weather enable Weave Scope or not"
  type        = bool
  default     = false
}

variable "bindings" {
  description = "Variable which describes group and role binding"
  type = list(object({
    group     = string
    namespace = string
    roles     = list(string)

  }))
  default = []
}

variable "roles" {
  description = "Variable describes which role will user have K8s"
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "enable_sso_rbac" {
  description = "Enable SSO RBAC integration or not"
  type        = bool
  default     = false
}
