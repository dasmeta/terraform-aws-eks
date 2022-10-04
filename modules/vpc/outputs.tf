output "id" {
  value       = try(module.vpc[0].vpc_id, null)
  description = "The newly created vpc id"
}

output "private_subnets" {
  value       = try(module.vpc[0].private_subnets, null)
  description = "The newly created vpc private subnets IDs list"
}

output "public_subnets" {
  value       = try(module.vpc[0].public_subnets, null)
  description = "The newly created vpc public subnets IDs list"
}

output "cidr_block" {
  value       = try(module.vpc[0].vpc_cidr_block, null)
  description = "The cidr block of the vpc"
}

output "default_security_group_id" {
  value       = try(module.vpc[0].default_security_group_id, null)
  description = "The ID of default security group created"
}

output "nat_public_ips" {
  value       = try(module.vpc[0].nat_public_ips, null)
  description = "The list of elastic public IPs"
}
