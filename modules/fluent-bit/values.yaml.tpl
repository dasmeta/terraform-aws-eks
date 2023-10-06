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
        Match         app.*
        Exclude       $message ${log_filters}

    [FILTER]
        Name          grep
        Match         app.*
        Exclude       $message ${additional_log_filters}

    [FILTER]
        Name          grep
        Match         kube.*
        Exclude       $kubernetes['namespace_name'] ${drop_namespaces}

    ${indent(4, filters)}
  outputs: |
    [OUTPUT]
        Name cloudwatch_logs
        Match   *
        region ${region}
        log_group_name ${log_group_name}
        log_stream_prefix from-fluent-bit-
        auto_create_group ${auto_create_group}
        log_retention_days ${log_retention_days}

    [OUTPUT]
        Name cloudwatch_logs
        Match  kube.*
        region ${region}
        log_group_name ${system_log_group_name}
        log_stream_prefix from-fluent-bit-
        auto_create_group ${auto_create_group}
        log_retention_days ${log_retention_days}

    ${indent(4, outputs)}
