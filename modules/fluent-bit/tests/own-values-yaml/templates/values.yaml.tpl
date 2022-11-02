config:
  outputs: |
    [OUTPUT]
        Name cloudwatch_logs
        Match host.*
        region ${region}
        log_group_name ${log_group_name_system}
        log_stream_prefix eks-
        auto_create_group Off
        log_retention_days ${log_retention_days}

    [OUTPUT]
        Name cloudwatch_logs
        Match kube.*
        region ${region}
        log_group_name ${log_group_name_system}
        log_stream_prefix eks-
        auto_create_group Off
        log_retention_days ${log_retention_days}
        log_stream_template $kubernetes['pod_name'].$kubernetes['container_name']

    [OUTPUT]
        Name cloudwatch_logs
        Match app.*
        region ${region}
        log_group_name ${log_group_name_application}
        log_stream_prefix app-logs-
        auto_create_group Off
        log_retention_days ${log_retention_days}
        log_stream_template $kubernetes['labels']['app'].$kubernetes['container_name']

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude On

    [FILTER]
        Name          rewrite_tag
        Match         kube.*
        Rule          $kubernetes['namespace_name'] ^(application.*)$ app.$TAG false
