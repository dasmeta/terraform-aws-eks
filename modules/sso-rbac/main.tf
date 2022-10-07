/**
 * ### This is basic usage of module `sso-rbac`
 *
 * ```
 * module "sso-rbac" {
 *   source     = "dasmeta/eks/aws//modules/sso-rbac"
 *   roles      = var.roles
 *   bindings   = var.bindings
 *   eks_module = module.eks-cluster.eks_module
 *   account_id = var.account_id
 * }
 *
 * locals {
 *
 *   roles = [{
 *     name      = "viewers"
 *     actions   = ["get", "list", "watch"]
 *     resources = ["deployments"]
 *   }, {
 *     name      = "editors"
 *     actions   = ["get", "list", "watch"]
 *     resources = ["pods"]
 *   }]
 *
 *   bindings = [{
 *     group     = "developers"
 *     namespace = "development"
 *     roles     = ["viewers", "editors"]
 *
 *   }, {
 *     group     = "accountants"
 *     namespace = "accounting"
 *     roles     = ["editors"]
 *  }]
 * }
 * ```
 **/
