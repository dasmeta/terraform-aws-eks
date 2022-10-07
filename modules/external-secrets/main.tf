/**
 * # How to use
 * This needs to be included in eks cluster along side with other services.
 *
 * At this stage it does not require any credentials.
 *
 * ```
 * module external-secrets-staging {
 *   source = "dasmeta/terraform/modules/external-secrets"
 * }
 * ```
 *
 * After this one has to deploy specific stores which do contain credentials to pull secrets from AWS Secret Manager.
 *
 * See related modules:
 * - external-secret-store
 * - aws-secret
 */

module "release" {
  source  = "terraform-module/release/helm"
  version = "2.8.0"

  namespace  = var.namespace
  repository = "https://charts.external-secrets.io"

  app = {
    name          = "external-secrets"
    version       = "0.4.4" # upgrade to >= 0.5.x requires some changes in base chart also where we use crd for defining secrets, look for detail https://external-secrets.io/v0.5.0/guides-v1beta1/
    chart         = "external-secrets"
    recreate_pods = false
    deploy        = 1
  }
}
