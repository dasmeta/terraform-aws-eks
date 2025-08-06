module "this" {
  source = "../../"

  cluster_name = "test-node-local-dns-enabled"

  vpc = {
    link = {
      id                 = data.aws_vpcs.ids.ids[0]
      private_subnet_ids = data.aws_subnets.subnets.ids
    }
  }

  node_groups = {
    "default" : {
      "desired_size" : 1,
      "max_capacity" : 1,
      "max_size" : 1,
      "min_size" : 1
    }
  }
  node_groups_default = {
    "capacity_type" : "SPOT",
    "instance_types" : ["t3.medium"]
  }

  alarms = {
    enabled   = false
    sns_topic = ""
  }
  enable_ebs_driver            = false
  enable_external_secrets      = false
  create_cert_manager          = false
  enable_node_problem_detector = false
  metrics_exporter             = "disabled"
  fluent_bit_configs = {
    enabled = false
  }

  nginx_ingress_controller_config = {
    enabled      = true
    replicacount = 1
  }

  external_dns = {
    enabled = true
    configs = {
      configs = { sources = ["service", "ingress"] }
    }
  }

  linkerd = {
    enabled = false
  }

  keda = {
    enabled = false
  }

  default_addons = { "coredns" : {
    "configuration_values" : { "affinity" : { "nodeAffinity" : { "requiredDuringSchedulingIgnoredDuringExecution" : { "nodeSelectorTerms" : [{ "matchExpressions" : [{ "key" : "kubernetes.io/os", "operator" : "In", "values" : ["linux"] }, { "key" : "kubernetes.io/arch", "operator" : "In", "values" : ["amd64", "arm64"] }, { "key" : "karpenter.sh/capacity-type", "operator" : "NotIn", "values" : ["spot"] }] }] } }, "podAntiAffinity" : { "preferredDuringSchedulingIgnoredDuringExecution" : [{ "podAffinityTerm" : { "labelSelector" : { "matchExpressions" : [{ "key" : "k8s-app", "operator" : "In", "values" : ["kube-dns"] }] }, "topologyKey" : "kubernetes.io/hostname" }, "weight" : 100 }] } }, "corefile" : ".:53 {\n    errors\n    health {\n        lameduck 5s\n      }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n      pods insecure\n      fallthrough in-addr.arpa ip6.arpa\n      ttl 120\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n      max_concurrent 10\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n", "replicaCount" : 1, "resources" : { "limits" : { "memory" : "171Mi" }, "requests" : { "cpu" : "100m", "memory" : "70Mi" } }, "tolerations" : [{ "effect" : "NoSchedule", "key" : "node-role.kubernetes.io/control-plane" }, { "key" : "CriticalAddonsOnly", "operator" : "Exists" }, { "effect" : "NoSchedule", "key" : "nodegroup", "operator" : "Equal", "value" : "on-demand" }] }, "most_recent" : true }
  }

  # here we enable localdns to have dns caching active
  node_local_dns = {
    enabled : true
  }
}

resource "helm_release" "http_echo" {
  name       = "http-echo"
  repository = "https://dasmeta.github.io/helm"
  chart      = "base"
  namespace  = "default"
  version    = "0.3.13"
  wait       = true

  values = [file("${path.module}/http-echo-node-local-dns.yaml")]

  depends_on = [module.this]
}
