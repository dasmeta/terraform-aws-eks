variable "create" {
  type        = bool
  default     = true
  description = "Whether to create cluster and other resources or not"
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
      min_size                     = 2
      max_size                     = 4
      desired_size                 = 2
      instance_types               = ["t3.medium"]
      iam_role_additional_policies = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
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
    ingress_cluster_10250 = {
      description = "Metric server to node groups"
      protocol    = "tcp"
      from_port   = 10250
      to_port     = 10250
      type        = "ingress"
      self        = true
    }
  }
}

variable "node_groups_default" {
  description = "Map of EKS managed node group default configurations"
  type        = any
  default = {
    disk_size                    = 50
    instance_types               = ["t3.medium"]
    iam_role_additional_policies = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
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
  type        = list(any)
  default     = []
  description = "List of users to open eks cluster api access"
}

# ALB-INGRESS-CONTROLLER
variable "alb_log_bucket_path" {
  type    = string
  default = ""
}

variable "send_alb_logs_to_cloudwatch" {
  type        = bool
  default     = true
  description = "Whether send alb logs to CloudWatch or not."
}

variable "alb_log_bucket_name" {
  type    = string
  default = ""
}

# FLUENT-BIT

variable "fluent_bit_configs" {
  type = object({
    fluent_bit_name       = optional(string, "")
    log_group_name        = optional(string, "")
    system_log_group_name = optional(string, "")
    log_retention_days    = optional(number, 90)
    values_yaml           = optional(string, "")
    configs = optional(object({
      inputs  = optional(string, "")
      filters = optional(string, "")
      outputs = optional(string, "")
    }), {})
    drop_namespaces        = optional(list(string), [])
    log_filters            = optional(list(string), [])
    additional_log_filters = optional(list(string), [])
    kube_namespaces        = optional(list(string), [])
  })
  default = {
    fluent_bit_name       = ""
    log_group_name        = ""
    system_log_group_name = ""
    log_retention_days    = 90
    values_yaml           = ""
    configs = {
      inputs  = ""
      outputs = ""
      filters = ""
    }
    drop_namespaces = [
      "kube-system",
      "opentelemetry-operator-system",
      "adot",
      "cert-manager",
      "opentelemetry.*",
      "meta.*",
    ]
    log_filters = [
      "kube-probe",
      "health",
      "prometheus",
      "liveness"
    ]
    additional_log_filters = [
      "ELB-HealthChecker",
      "Amazon-Route53-Health-Check-Service",
    ]
    kube_namespaces = [
      "kube.*",
      "meta.*",
      "adot.*",
      "devops.*",
      "cert-manager.*",
      "git.*",
      "opentelemetry.*",
      "stakater.*",
      "renovate.*"
    ]
  }
  description = "Fluent Bit configs"
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
  default     = []
}

variable "cluster_version" {
  description = "Allows to set/change kubernetes cluster version, kubernetes version needs to be updated at leas once a year. Please check here for available versions https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
  type        = string
  default     = "1.27"
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

variable "account_id" {
  type        = string
  default     = null
  description = "AWS Account Id to apply changes into"
}

variable "region" {
  type        = string
  default     = null
  description = "AWS Region name."
}

variable "vpc" {
  type = object({
    # for linking using existing vpc
    link = optional(object({
      id                 = string
      private_subnet_ids = list(string)
    }), { id = null, private_subnet_ids = null })
    # for creating new vpc
    create = optional(object({
      name                = string
      availability_zones  = list(string)
      cidr                = string
      private_subnets     = list(string)
      public_subnets      = list(string)
      public_subnet_tags  = optional(map(any), {})
      private_subnet_tags = optional(map(any), {})
    }), { name = null, availability_zones = null, cidr = null, private_subnets = null, public_subnets = null })
  })

  # default     = {}
  description = "VPC configuration for eks, we support both cases create new vpc(create field) and using already created one(link)"

  validation {
    condition     = (try(var.vpc.link.id, null) != null || try(var.vpc.create.name, null) != null) && (try(var.vpc.link.id, null) == null || try(var.vpc.create.name, null) == null)
    error_message = "One of(just one, not both) vpc.link.* and vpc.create.* field list is must to set for vpc configuration"
  }
}

variable "metrics_exporter" {
  type        = string
  default     = "cloudwatch"
  description = "Metrics Exporter, can use cloudwatch or adot"
}

variable "adot_config" {
  type = any
  default = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = {}
    log_group_name         = "adot_log_group"
  }
}

variable "adot_version" {
  description = "The version of the AWS Distro for OpenTelemetry addon to use."
  type        = string
  default     = "v0.78.0-eksbuild.1"
}

variable "enable_kube_state_metrics" {
  type        = bool
  default     = false
  description = "Enable kube-state-metrics"
}

// Cert manager
// If you want enable ADOT you should enable cert_manager
variable "create_cert_manager" {
  description = "If enabled it always gets deployed to the cert-manager namespace."
  type        = bool
  default     = false
}

variable "enable_efs_driver" {
  type        = bool
  default     = false
  description = "Weather install EFS driver or not in EKS"
}

variable "efs_id" {
  description = "EFS filesystem id in AWS"
  type        = string
  default     = null
}

variable "autoscaling" {
  description = "Weather enable autoscaling or not in EKS"
  type        = bool
  default     = false
}

variable "autoscaler_image_patch" {
  type        = number
  description = "The patch number of autoscaler image"
  default     = 0
}

variable "scale_down_unneeded_time" {
  type        = number
  description = "Scale down unneeded in minutes"
  default     = 2
}

variable "enable_ebs_driver" {
  description = "Weather enable EBS-CSI driver or not"
  type        = bool
  default     = true
}

variable "ebs_csi_version" {
  description = "EBS CSI driver addon version"
  type        = string
  default     = "v1.15.0-eksbuild.1"
}

variable "autoscaler_limits" {
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "600Mi"
  }
}

variable "autoscaler_requests" {
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "600Mi"
  }
}

variable "enable_api_gw_controller" {
  description = "Weather enable API-GW controller or not"
  type        = bool
  default     = false
}

variable "api_gw_deploy_region" {
  description = "Region in which API gatewat will be configured"
  type        = string
  default     = ""
}

variable "api_gateway_resources" {
  description = "Nested map containing API, Stage, and VPC Link resources"
  default     = []
  type = list(object({
    namespace = string
    api = object({
      name         = string
      protocolType = string
    })
    stages = optional(list(object({
      name        = string
      namespace   = string
      apiRef_name = string
      stageName   = string
      autoDeploy  = bool
      description = string
    })))
    vpc_links = optional(list(object({
      name      = string
      namespace = string
    })))
  }))
}
variable "enable_node_problem_detector" {
  type    = bool
  default = true
}

variable "enable_olm" {
  type        = bool
  default     = false
  description = "To install OLM controller (experimental)."
}

variable "prometheus_metrics" {
  description = "Prometheus Metrics"
  type        = any
  default     = []
}
