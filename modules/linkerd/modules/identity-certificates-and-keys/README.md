## terraform sub-sub-module to generate required linkerd helm setup identity certificates and keys to use in main sub-module

We need to generate certificate for linkerd identity module, and this module intended to generate those certificates/keys in terraform so that there will not be need to do manual actions,

Based on doc we use step tool https://linkerd.io/2.18/tasks/generate-certificates/, there are cli commands to generate those certificates, and here are commands that doc provides to manually generate the certificates/keys,
This command are put here just to show how manually one can create certificates in case one need to do manual generation, but in general there will not be need to run and generate manually as this module will create needed data automatically:
```sh
# install brew `step` tool, https://smallstep.com/docs/step-cli/installation/
brew install step

# generate certificate ca.crt and ca.key files, the content of ca.crt is one to pass as value for `identityTrustAnchorsPEM` param (timeout is set 187600h=21 year)
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure --not-after=187600h

#  generate issuer.crt and issuer.key files based on above generated ca.crt and ca.key files, so that `identity.issuer.tls.crtPEM` content is issuer.crt and `identity.issuer.tls.keyPEM` config content is issuer.key (timeout is set 187600h=21 year)
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key --profile intermediate-ca --not-after 187600h --no-password --insecure --ca ca.crt --ca-key ca.key
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
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
| [tls_cert_request.issuer_req](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.issuer_cert](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.issuer_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.trust_anchor_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.trust_anchor_cert](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_validity_period_hours"></a> [validity\_period\_hours](#input\_validity\_period\_hours) | The number of hours, after initial issuing, that the certificates will remain valid for. The default `187600` one is >21 years. | `number` | `187600` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The generated and required config field for linkerd identity module, this configs usually being generated/passed automatically when we use `linkerd` cli to install linkerd, but for terraform/helm install we need to generate them, for more info check README.md |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
