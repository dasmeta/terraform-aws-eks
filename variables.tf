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
      instance_types               = ["t3.large"]
      iam_role_additional_policies = { CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" }
    }
  }
}

variable "node_security_group_additional_rules" {
  type = any
  default = {
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
    instance_types               = ["t3.large"]
    iam_role_additional_policies = { CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" }
  }
}

variable "workers_group_defaults" {
  type = any

  default = {
    launch_template_use_name_prefix = true
    launch_template_name            = "default"
    root_volume_type                = "gp3"
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
variable "alb_load_balancer_controller" {
  type = object({
    enabled                     = optional(bool, true)  # Whether alb ingress/load-balancer controller enabled, note that alb load balancer will be created also when nginx_ingress_controller_config.enabled=true as nginx loadbalancer service needs it
    enable_waf_for_alb          = optional(bool, false) # Enables WAF and WAF V2 addons for ALB
    configs                     = optional(any, {})     # allows to pass additional helm chart configs
    alb_log_bucket_name         = optional(string, "")  # The s3 bucket where alb logs will be placed, TODO: option and its related ability disable, check if we need this ability
    alb_log_bucket_path         = optional(string, "")  # The s3 bucket path/folder where alb logs will be placed, TODO: option and its related ability disable, check if we need this ability
    send_alb_logs_to_cloudwatch = optional(bool, true)  # Whether logs will be pushed to cloudwatch also, TODO: option and its related ability disable, check if we need this ability
  })
  default     = {}
  description = "Aws alb ingress/load-balancer controller configs."
}

# FLUENT-BIT

variable "fluent_bit_configs" {
  type = object({
    enabled               = optional(string, false) # before default was `true`, we disable fluentbit by default as we are now using separate grafana stack setup module as k8s metric/log/trace collection tools
    fluent_bit_name       = optional(string, "")
    log_group_name        = optional(string, "")
    system_log_group_name = optional(string, "")
    log_retention_days    = optional(number, 90)
    values_yaml           = optional(string, "")
    s3_permission         = optional(bool, false)
    configs = optional(object({
      inputs                     = optional(string, "")
      filters                    = optional(string, "")
      outputs                    = optional(string, "")
      cloudwatch_outputs_enabled = optional(bool, true)
    }), {})
    drop_namespaces        = optional(list(string), [])
    log_filters            = optional(list(string), [])
    additional_log_filters = optional(list(string), [])
    kube_namespaces        = optional(list(string), [])
    image_pull_secrets     = optional(list(string), [])
  })
  default = {
    enabled               = false
    fluent_bit_name       = ""
    log_group_name        = ""
    system_log_group_name = ""
    log_retention_days    = 90
    values_yaml           = ""
    image_pull_secrets    = []
    s3_permission         = false
    configs = {
      inputs                     = ""
      outputs                    = ""
      filters                    = ""
      cloudwatch_outputs_enabled = true # whether to disable default cloudwatch exporter/output
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

variable "enable_external_secrets" {
  type        = bool
  description = "Whether to enable external-secrets operator"
  default     = true
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
  default     = "1.31"
}

variable "cluster_addons" {
  description = "Cluster addon configurations to enable."
  type        = any
  default     = {}
}

variable "default_addons" {
  description = "Allows to set/override default eks addons(like coredns, kube-proxy and aws-cni) configurations."
  type        = any
  default = {
    coredns = {
      most_recent = true
      configuration_values = { # can be here we have defaults for replica count, resource request/limits and corefile config file, in case there are dns resolve issues on high load websites check to increase limits
        replicaCount = 2
        resources = {
          limits = {
            memory = "171Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "70Mi"
          }
        }
        # this is main coredns config file and in case you get domain name resolution errors check ttl and max_concurrent values, NOTE: that for example increasing max_concurrent value requires also increase to memory 2kb per connection, check docs here: https://coredns.io/plugins/forward/
        corefile = <<EOT
        .:53 {
            errors
            health {
                lameduck 5s
              }
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
              ttl 120
            }
            prometheus :9153
            forward . /etc/resolv.conf {
              max_concurrent 2000
            }
            cache 30
            loop
            reload
            loadbalance
        }
        EOT
      }
    }
  }
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
      private_subnet_ids = list(string) # please have the existing vpc public/private subnets(at least 2 needed) tagged with corresponding tags(look into create case subnet tags defaults)
    }), { id = null, private_subnet_ids = null })
    # for creating new vpc
    create = optional(object({
      name                = string
      availability_zones  = list(string)
      cidr                = string
      private_subnets     = list(string)
      public_subnets      = list(string)
      public_subnet_tags  = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/elb" = 1}
      private_subnet_tags = optional(map(any), {}) # to pass additional tags for public subnet or override default ones. The default ones are: {"kubernetes.io/cluster/${var.cluster_name}" = "shared","kubernetes.io/role/internal-elb" = 1}
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
  default     = "none" # before default was "adot", we disable by default `adot` as we are now using separate grafana stack setup module as k8s metric/log/trace collection tools
  description = "Metrics Exporter, can use `cloudwatch` or `adot`"
}

variable "nginx_ingress_controller_config" {
  type = object({
    enabled          = optional(bool, false)
    name             = optional(string, "nginx")
    create_namespace = optional(bool, true)
    namespace        = optional(string, "ingress-nginx")
    replicacount     = optional(number, 3)
    metrics_enabled  = optional(bool, true)
    configs          = optional(any, {}) # Configurations to pass and override default ones. Check the helm chart available configs here: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx/4.12.0?modal=values
  })

  default = {
    enabled          = false
    name             = "nginx"
    create_namespace = true
    namespace        = "ingress-nginx"
    replicacount     = 3
    metrics_enabled  = true
  }

  description = "Nginx ingress controller configs"
}

variable "adot_config" {
  description = "accept_namespace_regex defines the list of namespaces from which metrics will be exported, and additional_metrics defines additional metrics to export."
  type = object({
    accept_namespace_regex = optional(string, "(default|kube-system)")
    additional_metrics     = optional(list(string), [])
    log_group_name         = optional(string, "adot")
    log_retention          = optional(number, 14)
    helm_values            = optional(any, null)
    logging_enable         = optional(bool, false)
    resources = optional(object({
      limit = object({
        cpu    = optional(string, "200m")
        memory = optional(string, "200Mi")
      })
      requests = object({
        cpu    = optional(string, "200m")
        memory = optional(string, "200Mi")
      })
      }), {
      limit = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "200Mi"
      }
    })
  })
  default = {
    accept_namespace_regex = "(default|kube-system)"
    additional_metrics     = []
    log_group_name         = "adot"
    log_retention          = 14
    logging_enable         = false
    helm_values            = null
    resources = {
      limit = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "200Mi"
      }
    }
  }
}

variable "adot_version" {
  description = "The version of the AWS Distro for OpenTelemetry addon to use. If not passed it will get compatible version based on cluster_version"
  type        = string
  default     = null
}

variable "enable_kube_state_metrics" {
  type        = bool
  default     = false
  description = "Enable kube-state-metrics"
}

variable "kube_state_metrics_chart_version" {
  type        = string
  default     = "5.27.0"
  description = "The kube-state-metrics chart version"
}

// Cert manager
// If you want enable ADOT you should enable cert_manager
variable "create_cert_manager" {
  description = "If enabled it always gets deployed to the cert-manager namespace."
  type        = bool
  default     = false
}
variable "cert_manager_chart_version" {
  description = "The cert-manager helm chart version."
  type        = string
  default     = "1.16.2"
}

variable "enable_efs_driver" {
  type        = bool
  default     = false
  description = "Weather install EFS driver or not in EKS"
}

variable "efs_storage_classes" {
  description = "Additional storage class configurations: by default, 2 storage classes are created - efs-sc and efs-sc-root which has 0 uid. One can add another storage classes besides these 2."
  type = list(object({
    name : string
    provisioning_mode : optional(string, "efs-ap")
    file_system_id : string
    directory_perms : optional(string, "755")
    base_path : optional(string, "/")
    uid : optional(number)
  }))
  default = []
}

variable "efs_id" {
  description = "EFS filesystem id in AWS"
  type        = string
  default     = null
}

variable "autoscaling" {
  description = "Weather enable cluster autoscaler for EKS, in case if karpenter enabled this config will be ignored and the cluster autoscaler will be considered as disabled"
  type        = bool
  default     = true
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
  description = "EBS CSI driver addon version, by default it will pick right version for this driver based on cluster_version"
  type        = string
  default     = null
}

variable "s3_csi" {
  type = object({
    enabled       = optional(bool, false)
    addon_version = optional(string, null)     # if not passed it will use latest compatible version
    buckets       = optional(list(string), []) # the name of buckets to create policy to be able to mount them to containers, if not specified it uses all/*
    configs = optional(object({                # allows to pass additional addon configs to override default ones
      node = optional(object({
        tolerateAllTaints = optional(bool, true) # Whether mountpoint for S3 CSI Driver Pods will tolerate all taints and will be scheduled in all nodes
      }), {})
    }), {})
  })
  default     = {}
  description = "S3 CSI driver addon version, by default it will pick right version for this driver based on cluster_version"
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

variable "enable_portainer" {
  description = "Enable Portainer provisioning or not"
  type        = bool
  default     = false
}

variable "portainer_config" {
  description = "Portainer hostname and ingress config."
  type = object({
    host           = optional(string, "portainer.dasmeta.com")
    enable_ingress = optional(bool, true)
  })
  default = {}
}

variable "alarms" {
  type = object({
    enabled       = optional(bool, false) # we need to have cloudwatch metrics based alarms disabled by default, as we disabled adot/cloudwatch metric exporters by default.
    sns_topic     = optional(string, "")
    custom_values = optional(any, {})
  })
  default     = {}
  description = "Creates cloudwatch alarms  on ContainerInsights `cluster_failed_node_count` metric. If one of adot/cloudwatch metrics_exporters is not enabled then we have to disable alarms as specified metric do not exist and creation may fail. You need set sns topic name if you enable alarms. For customize alarms threshold use custom_values"
}

variable "additional_priority_classes" {
  type = list(object({
    name  = string
    value = string # number in string form
  }))
  description = "Defines Priority Classes in Kubernetes, used to assign different levels of priority to pods. By default, this module creates three Priority Classes: 'high'(1000000), 'medium'(500000) and 'low'(250000) . You can also provide a custom list of Priority Classes if needed."
  default     = []
}

variable "external_dns" {
  type = object({
    enabled = optional(bool, false)
    configs = optional(any, {})
  })
  default = {
    enabled = false
  }
  description = "Allows to install external-dns helm chart and related roles, which allows to automatically create R53 records based on ingress/service domain/host configs"
}

variable "flagger" {
  type = object({
    enabled                    = optional(bool, false)
    namespace                  = optional(string, "ingress-nginx") # The flagger operator helm being installed on same namespace as mesh/ingress provider so this field need to be set based on which ingress/mesh we are going to use, more info in https://artifacthub.io/packages/helm/flagger/flagger
    configs                    = optional(any, {})                 # Available options can be found in https://artifacthub.io/packages/helm/flagger/flagger
    metrics_and_alerts_configs = optional(any, {})                 # Available options can be found in https://github.com/dasmeta/helm/tree/flagger-metrics-and-alerts-0.1.0/charts/flagger-metrics-and-alerts
    enable_loadtester          = optional(bool, false)             # Whether to install flagger loadtester helm
  })
  default = {
    enabled = false
  }
  description = "Allows to create/deploy flagger operator to have custom rollout strategies like canary/blue-green and also it allows to create custom flagger metric templates"
}

variable "karpenter" {
  type = object({
    enabled                   = optional(bool, true)
    configs                   = optional(any, {})                               # karpenter chart configs, the underlying module sets some general/default ones, available option can be found here: https://github.com/aws/karpenter-provider-aws/blob/v1.0.8/charts/karpenter/values.yaml
    resource_configs          = optional(any, { nodePools = { general = {} } }) # karpenter resources creation configs, available options can be fount here: https://github.com/dasmeta/helm/tree/karpenter-resources-0.1.0/charts/karpenter-resources
    resource_configs_defaults = optional(any, {})                               # the default used for karpenter node pool creation, the available values to override/set can be found in karpenter submodule corresponding variable modules/karpenter/values.tf
  })
  default = {
    enabled = true
  }
  description = "Allows to create/deploy/configure karpenter operator and its resources to have custom node auto-calling"
}

variable "keda" {
  type = object({
    enabled          = optional(bool, true)
    name             = optional(string, "keda")   # keda chart name,
    namespace        = optional(string, "keda")   # keda chart namespace
    create_namespace = optional(bool, true)       # create keda chart
    keda_version     = optional(string, "2.16.1") # chart version
    attach_policies = optional(object({
      sqs = bool
    }), { sqs = false })
    keda_trigger_auth_additional = optional(any, null)
  })
  default = {
    enabled          = true
    name             = "keda"
    namespace        = "keda"
    create_namespace = true
    keda_version     = "2.16.1"
  }
  description = "Allows to create/deploy/configure keda"
}

variable "namespaces_and_docker_auth" {
  type = object({
    enabled = optional(bool, false)
    list    = optional(list(string), []) # list of application namespaces to create/init with cluster creation
    labels  = optional(any, {})          # map of key=>value strings to attach to namespaces
    dockerAuth = optional(object({       # docker hub image registry configs, this based external secrets operator(operator should be enabled). which will allow to create 'kubernetes.io/dockerconfigjson' type secrets in app(and also all other) namespaces and configure app namespaces to use this
      enabled                 = optional(bool, false)
      refreshTime             = optional(string, "3m")                                         # frequency to check filtered namespaces and create ExternalSecrets (and k8s secret)
      refreshInterval         = optional(string, "1h")                                         # frequency to pull/refresh data from aws secret
      name                    = optional(string, "docker-registry-auth")                       # the name to use when creating k8s resources
      secretManagerSecretName = optional(string, "account")                                    # aws secret manager secret name where dockerhub credentials placed, we use "account" default secret
      namespaceSelector       = optional(any, { matchLabels : { "docker-auth" = "enabled" } }) # namespaces selector expression, the app namespaces created here will have this selectors by default, but for other namespaces you may need to set labels manually. this can be set to empty object {} to create secrets in all namespaces
      registries = optional(list(object({                                                      # docker registry configs
        url         = optional(string, "https://index.docker.io/v1/")                          # docker registry server url
        usernameKey = optional(string, "DOCKER_HUB_USERNAME")                                  # the aws secret manager secret key where docker registry username placed
        passwordKey = optional(string, "DOCKER_HUB_PASSWORD")                                  # the aws secret manager secret key where docker registry password placed, NOTE: for dockerhub under this key should be set personal access token instead of standard ui/profile password
        authKey     = optional(string)                                                         # the aws secret manager secret key where docker registry auth placed
      })), [{ url = "https://index.docker.io/v1/", usernameKey = "DOCKER_HUB_USERNAME", passwordKey = "DOCKER_HUB_PASSWORD", authKey = null }])
    }), { enabled = false })
  })
  default     = {}
  description = "Allows to create application namespaces, like 'prod' or 'dev' automatically. it can also set to use docker hub credential for image pull"
}

variable "linkerd" {
  type = object({
    enabled     = optional(bool, true)
    configs     = optional(any, {})    # allows to override default configs of linkerd main helm chart, check underlying sub-module module for more info
    configs_viz = optional(any, {})    # allows to override default configs of linkerd viz helm chart, check underlying sub-module module for more info
    crds_create = optional(bool, true) # whether to have linkerd crd installed
    viz_create  = optional(bool, true) # whether to have linkerd monitoring/dashboard tooling installed
  })
  default = {
    enabled = true
  }
  description = "Allows to create/configure linkerd in eks cluster"
}

variable "event_exporter" {
  type = object({
    enabled = optional(bool, false)
    configs = optional(any, {})
  })
  default = {
    enabled = false
    ## example of configs
    # configs = {
    #   config = {
    #     receivers = [
    #       {
    #         name = "webhook-prod"
    #         webhook = {
    #           endpoint = "https://n8n.dasmeta.com/webhook/<n8n-webhook-trigger-id>?accountId=<accountId-in-cloudbrowser>" # not a real one
    #         }
    #       }
    #     ]
    #     route = {
    #       routes = [
    #         {
    #           match = [{ receiver : "webhook-prod" }]
    #         }
    #       ]
    #     }
    #   }
    # }
  }
  description = "Allows to create/configure event_exporter in eks cluster. The configs option is object to pass corresponding to preferred helm values.yaml, for more details check: https://artifacthub.io/packages/helm/bitnami/kubernetes-event-exporter?modal=values"
}

variable "tags" {
  description = "Extra tags to attach to eks cluster."
  type        = any
  default     = {}
}
