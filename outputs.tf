### CLUSTER
output "oidc_provider_arn" {
  value = try(module.eks-cluster[0].oidc_provider_arn, null)
}

output "eks_oidc_root_ca_thumbprint" {
  value       = local.eks_oidc_root_ca_thumbprint
  description = "Grab eks_oidc_root_ca_thumbprint from oidc_provider_arn."
}

output "cluster_id" {
  value = try(module.eks-cluster[0].cluster_name, null)
}

output "cluster_iam_role_name" {
  value = try(module.eks-cluster[0].cluster_iam_role_name, null)
}

output "cluster_security_group_id" {
  value = try(module.eks-cluster[0].cluster_security_group_id, null)
}

output "cluster_primary_security_group_id" {
  value = try(module.eks-cluster[0].cluster_primary_security_group_id, null)
}

output "map_user_data" {
  value = try(module.eks-cluster[0].map_users_data, null)
}

# output "cluster_name" {
#   value = module.eks-cluster[0].cluster_name
# }

output "cluster_host" {
  value       = try(module.eks-cluster[0].host, null)
  description = "EKS cluster host name used for authentication/access in helm/kubectl/kubernetes providers"
}

output "cluster_certificate" {
  value       = try(module.eks-cluster[0].certificate, null)
  description = "EKS cluster certificate used for authentication/access in helm/kubectl/kubernetes providers"
}

output "cluster_token" {
  value       = try(module.eks-cluster[0].token, null)
  description = "EKS cluster token used for authentication/access in helm/kubectl/kubernetes providers"
}

### VPC
output "vpc_cidr_block" {
  value       = try(module.vpc[0].cidr_block, null)
  description = "The cidr block of the vpc"
}

output "vpc_id" {
  value       = try(module.vpc[0].id, null)
  description = "The newly created vpc id"
}

output "vpc_private_subnets" {
  value       = try(module.vpc[0].private_subnets, null)
  description = "The newly created vpc private subnets IDs list"
}

output "vpc_public_subnets" {
  value       = try(module.vpc[0].public_subnets, null)
  description = "The newly created vpc public subnets IDs list"
}

output "vpc_default_security_group_id" {
  value       = try(module.vpc[0].default_security_group_id, null)
  description = "The ID of default security group created for vpc"
}

output "vpc_nat_public_ips" {
  value       = try(module.vpc[0].nat_public_ips, null)
  description = "The list of elastic public IPs for vpc"
}

output "role_arns" {
  value = try(module.sso-rbac[0].role_arns, "")
}

output "role_arns_without_path" {
  value = try(module.sso-rbac[0].role_arns_without_path, "")
}

output "eks_auth_configmap" {
  value     = try(module.sso-rbac[0].config_yaml, "")
  sensitive = true
}

output "eks_module" {
  value = try(module.eks-cluster[0].eks_module, null)
}

output "account_id" {
  value = local.account_id
}

output "region" {
  value = local.region
}

output "alb_load_balancer_controller" {
  description = "Combined AWS load balancer controller module output object."
  value       = try(module.alb-ingress-controller[0], null)
}

output "external_secret_deployment" {
  description = "Deprecated: the external-secrets module now installs the chart through a plain helm_release and no longer exposes a `deployment` object. Kept so existing references keep resolving; use `external_secrets` instead."
  value       = try(module.external-secrets[0].deployment, null)
}

output "external_secrets" {
  description = "External Secrets controller details. `controller_role_arn` is the base role each per-store role must trust, and is what the external-secret-store module expects as `controller_role_arn`."
  value = try({
    controller_role_arn    = module.external-secrets[0].controller_role_arn
    service_account        = module.external-secrets[0].service_account
    namespace              = module.external-secrets[0].namespace
    release_name           = module.external-secrets[0].release_name
    store_role_name_prefix = var.external_secrets.iam.store_role_name_prefix
  }, null)
}

output "namespaces_and_docker_auth_helm_metadata" {
  value = try(module.namespaces_and_docker_auth[0].helm_metadata, null)
}

output "cert_manager_cluster_issuer_names" {
  description = "Map of ClusterIssuer names created by cert-manager module"
  value       = try(module.cert-manager[0].cluster_issuer_names, {})
}

output "cert_manager_certificate_names" {
  value       = try(module.cert-manager[0].certificate_names, {})
  description = "Map of created cert-manager Certificate resource names by namespace/name"
}
