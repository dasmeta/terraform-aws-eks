# Module-level defaults for each chart. These are passed to helm_release as the
# first entry of its values[] list, with the user-supplied var.configs/
# var.configs_viz passed after them - Helm deep-merges the list itself, in
# order, with later entries winning, so no Terraform-side merge is needed.
locals {
  default_configs = {
    identityTrustAnchorsPEM = module.identity_certificates_and_keys.identity.trustAnchorsPEM
    identity = {
      issuer = {
        tls = {
          crtPEM = module.identity_certificates_and_keys.identity.issuerTlsCrtPEM
          keyPEM = module.identity_certificates_and_keys.identity.issuerTlsKeyPEM
        }
      }
    }
    proxyInjector               = module.webhook_certificates_and_keys.webhooks.proxyInjector
    profileValidator            = module.webhook_certificates_and_keys.webhooks.profileValidator
    policyValidator             = module.webhook_certificates_and_keys.webhooks.policyValidator
    destinationResources        = var.resourcesDefaults
    destinationProxyResources   = var.resourcesDefaults
    identityResources           = var.resourcesDefaults
    identityProxyResources      = var.resourcesDefaults
    proxyInjectorResources      = var.resourcesDefaults
    proxyInjectorProxyResources = var.resourcesDefaults
    spValidatorResources        = var.resourcesDefaults
    proxy = {
      resources = var.resourcesDefaults
    }
    policyController = {
      resources = var.resourcesDefaults
    }
  }

  default_configs_viz = {
    metricsAPI = {
      resources = var.resourcesDefaults
      proxy = {
        resources = var.resourcesDefaults
      }
    }
    tap = {
      resources = var.resourcesDefaults
      proxy = {
        resources = var.resourcesDefaults
      }
    }
    tapInjector = {
      resources = var.resourcesDefaults
      proxy = {
        resources = var.resourcesDefaults
      }
    }
    dashboard = {
      resources = var.resourcesDefaults
      proxy = {
        resources = var.resourcesDefaults
      }
    }
    prometheus = {
      resources = var.resourcesDefaults
      proxy = {
        resources = var.resourcesDefaults
      }
    }
  }
}
