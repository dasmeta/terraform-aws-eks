module "identity_certificates_and_keys" {
  source = "./modules/identity-certificates-and-keys"
}

module "custom_default_configs_together" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
    {
      identityTrustAnchorsPEM = module.identity_certificates_and_keys.identity.trustAnchorsPEM
      identity = {
        issuer = {
          tls = {
            crtPEM = module.identity_certificates_and_keys.identity.issuerTlsCrtPEM
            keyPEM = module.identity_certificates_and_keys.identity.issuerTlsKeyPEM
          }
        }
      }
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
    },
    var.configs
  ]
}

module "custom_default_configs_viz_together" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "1.0.2"

  maps = [
    {
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
    },
    var.configs_viz
  ]
}
