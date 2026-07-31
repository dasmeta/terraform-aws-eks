## terraform sub-sub-module to generate required linkerd-control-plane admission webhook certificates and keys to use in main sub-module

`linkerd-control-plane`'s three admission webhooks (proxy injector, service profile validator, policy validator) each need their own TLS serving certificate. If none is provided, Helm generates one automatically at install time - but only with a 1-year validity and no rotation. Since these webhooks default to `failurePolicy: Ignore`, an expired certificate doesn't produce any error: Kubernetes just silently stops calling the webhook, and (for the proxy injector specifically) new pods stop getting the `linkerd-proxy` sidecar injected even though they're correctly annotated for it. This is easy to miss for a long time, since nothing surfaces the failure anywhere.

This module generates long-lived, self-signed certificates for all three webhooks instead, the same way `../identity-certificates-and-keys` already does for the mesh mTLS identity chain, so the same silent-expiry failure mode doesn't apply here too.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.3 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [tls_private_key.webhook](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.webhook](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace linkerd-control-plane is installed into. Used to build the DNS names each webhook certificate must be valid for (<service>.<namespace>.svc etc). | `string` | n/a | yes |
| <a name="input_validity_period_hours"></a> [validity\_period\_hours](#input\_validity\_period\_hours) | The number of hours, after initial issuing, that the certificates will remain valid for. The default `187600` one is >21 years. Matches the identity certificate default: the Helm chart's own self-generated webhook certs default to 1 year with no rotation, which silently breaks proxy injection and the profile/policy validating webhooks once expired (the webhooks default to failurePolicy: Ignore, so Kubernetes just skips them with no error). | `number` | `187600` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_webhooks"></a> [webhooks](#output\_webhooks) | crtPEM/keyPEM/caBundle for each of linkerd-control-plane's admission webhooks (proxyInjector, profileValidator, policyValidator), matching the exact Helm values keys those need. Generated in Terraform with a long validity\_period\_hours so they don't silently expire the way the chart's own self-generated 1-year webhook certs do (those webhooks default to failurePolicy: Ignore, so an expired cert breaks proxy injection/validation with no visible error). |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
