output "cluster_id" {
  value       = module.eks-cluster.cluster_name
  description = "The cluster_id has been deprecated and replaced with cluster_name starting from module version v19.x"
}

output "cluster_name" {
  value = module.eks-cluster.cluster_name
}

output "cluster_iam_role_name" {
  value = module.eks-cluster.cluster_iam_role_name
}

output "eks_oidc_root_ca_thumbprint" {
  value       = replace(module.eks-cluster.oidc_provider_arn, "/.*id//", "")
  description = "Grab eks_oidc_root_ca_thumbprint from oidc_provider_arn."
}

output "oidc_provider_arn" {
  value = module.eks-cluster.oidc_provider_arn
}

output "cluster_security_group_id" {
  value = module.eks-cluster.cluster_security_group_id
}

output "cluster_primary_security_group_id" {
  value = module.eks-cluster.cluster_primary_security_group_id
}

output "host" {
  value = module.eks-cluster.cluster_endpoint
}

output "certificate" {
  value = base64decode(module.eks-cluster.cluster_certificate_authority_data)
}

output "token" {
  value = data.aws_eks_cluster_auth.cluster.token
}
output "map_users_data" {
  value = local.map_users
}

output "eks_module" {
  value = try(module.eks-cluster, null)
}

output "aws_auth_module" {
  value = try(module.aws_auth_config_map, null)
}

output "subnet_ids" {
  value       = var.subnets
  description = "VPC subnet ids used for eks"
}
