### CLUSTER
output "oidc_provider_arn" {
  value = module.eks-cluster.oidc_provider_arn
}

output "eks_oidc_root_ca_thumbprint" {
  value       = local.eks_oidc_root_ca_thumbprint
  description = "Grab eks_oidc_root_ca_thumbprint from oidc_provider_arn."
}

output "cluster_id" {
  value = module.eks-cluster.cluster_id
}

output "cluster_iam_role_name" {
  value = module.eks-cluster.cluster_iam_role_name
}

output "cluster_security_group_id" {
  value = module.eks-cluster.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  value = module.eks-cluster.cluster_primary_security_group_id
}

output "map_user_data" {
  value = module.eks-cluster.map_users_data
}

# output "cluster_name" {
#   value = module.eks-cluster.cluster_name
# }

output "cluster_host" {
  value       = module.eks-cluster.host
  description = "EKS cluster host name used for authentication/access in helm/kubectl/kubernetes providers"
}

output "cluster_certificate" {
  value       = module.eks-cluster.certificate
  description = "EKS cluster certificate used for authentication/access in helm/kubectl/kubernetes providers"
}

output "cluster_token" {
  value       = module.eks-cluster.token
  description = "EKS cluster token used for authentication/access in helm/kubectl/kubernetes providers"
}

### VPC
output "vpc_cidr_block" {
  value       = module.vpc.cidr_block
  description = "The cidr block of the vpc"
}

output "vpc_id" {
  value       = module.vpc.id
  description = "The newly created vpc id"
}

output "vpc_private_subnets" {
  value       = module.vpc.private_subnets
  description = "The newly created vpc private subnets IDs list"
}

output "vpc_public_subnets" {
  value       = module.vpc.public_subnets
  description = "The newly created vpc public subnets IDs list"
}

output "vpc_default_security_group_id" {
  value       = module.vpc.default_security_group_id
  description = "The ID of default security group created for vpc"
}

output "vpc_nat_public_ips" {
  value       = module.vpc.nat_public_ips
  description = "The list of elastic public IPs for vpc"
}

output "role_arns" {
  value = try(module.sso-rbac[0].role_arns, "")
}

output "role_arns_without_path" {
  value = try(module.sso-rbac[0].role_arns_without_path, "")
}

output "eks_auth_configmap" {
  value = try(module.sso-rbac[0].config_yaml, "")
}

output "eks_module" {
  value = module.eks-cluster.eks_module
}
