variable "namespace" {
  type        = string
  description = "The namespace linkerd-control-plane is installed into. Used to build the DNS names each webhook certificate must be valid for (<service>.<namespace>.svc etc)."
}

variable "validity_period_hours" {
  type        = number
  default     = 187600
  description = "The number of hours, after initial issuing, that the certificates will remain valid for. The default `187600` one is >21 years. Matches the identity certificate default: the Helm chart's own self-generated webhook certs default to 1 year with no rotation, which silently breaks proxy injection and the profile/policy validating webhooks once expired (the webhooks default to failurePolicy: Ignore, so Kubernetes just skips them with no error)."
}
