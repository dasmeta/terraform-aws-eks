apiVersion: keda.sh/v1alpha1
kind: ClusterTriggerAuthentication
metadata:
  name: keda-trigger-auth-default
  namespace: ${namespace}
spec:
  podIdentity:
    provider: aws
