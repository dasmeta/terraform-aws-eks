imagePullSecrets: ${jsonencode(imagePullSecrets)}
config:
  ## https://docs.fluentbit.io/manual/pipeline/inputs
  inputs: |
    [INPUT]
        Name               tail
        Tag                kube.*
        Path               /var/log/containers/*.log
        Read_from_head     true
        multiline.parser   docker, cri
        Docker_Mode        On
        Parser             docker
        Mem_Buf_Limit      50MB

    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

    ${indent(4, inputs)}

  ## https://docs.fluentbit.io/manual/pipeline/filters
  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude On

    [FILTER]
        Name          grep
        Match         kube.*
        Exclude       $log ${log_filters}

    [FILTER]
        Name          grep
        Match         kube.*
        Exclude       $log ${additional_log_filters}

%{ for value in kube_namespaces }
    [FILTER]
        Name          rewrite_tag
        Match         kube.*
        Rule          $kubernetes['namespace_name'] ^${value}$ system.$TAG false
%{ endfor ~}

    [FILTER]
        Name          grep
        Match         *
        Exclude       $kubernetes['namespace_name'] ${drop_namespaces}

    ${indent(4, filters)}
  outputs: |

    %{ if cloudwatch_outputs_enabled }

    [OUTPUT]
        Name cloudwatch_logs
        Match  kube.*
        region ${region}
        log_group_name ${log_group_name}
        log_stream_prefix from-fluent-bit-
        auto_create_group ${auto_create_group}
        log_retention_days ${log_retention_days}

    [OUTPUT]
        Name cloudwatch_logs
        Match host.*
        region ${region}
        log_group_name ${system_log_group_name}
        log_stream_prefix eks-
        auto_create_group ${auto_create_group}
        log_retention_days ${log_retention_days}

    [OUTPUT]
        Name cloudwatch_logs
        Match  system.*
        region ${region}
        log_group_name ${system_log_group_name}
        log_stream_prefix from-fluent-bit-
        auto_create_group ${auto_create_group}
        log_retention_days ${log_retention_days}

    %{ endif ~}

    ${indent(4, outputs)}
