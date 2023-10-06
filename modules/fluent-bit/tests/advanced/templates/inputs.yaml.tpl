[INPUT]
    Name               tail
    Tag                test.*
    Path               /var/log/containers/*.log
    Read_from_head     true
    multiline.parser   docker, cri
    Docker_Mode        On
    Parser             docker
    Mem_Buf_Limit      50MB
