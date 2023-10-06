[OUTPUT]
    Name s3
    Match test.*
    bucket s3-bucket
    region eu-central-1
    total_file_size 250M
    s3_key_format /%Y/%m/%d/%H_%M_%S.gz
