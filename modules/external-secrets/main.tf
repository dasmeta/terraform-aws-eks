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
  version = "2.8.2"

  namespace  = var.namespace
  repository = "https://charts.external-secrets.io"

  app = {
    name          = "external-secrets"
    version       = var.chart_version
    chart         = "external-secrets"
    recreate_pods = false
    deploy        = 1
  }
}
