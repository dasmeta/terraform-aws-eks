[FILTER]
    Name          grep
    Match         kube.*
    Exclude       $log (test)

[FILTER]
    Name          grep
    Match         audit.*
    regex         $log (test)
