output "id" {
  value       = module.vpc.vpc_id
  description = "The newly created vpc id"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "The newly created vpc private subnets IDs list"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "The newly created vpc public subnets IDs list"
}

output "cidr_block" {
  value       = module.vpc.vpc_cidr_block
  description = "The cidr block of the vpc"
}

output "default_security_group_id" {
  value       = module.vpc.default_security_group_id
  description = "The ID of default security group created"
}

output "nat_public_ips" {
  value       = module.vpc.nat_public_ips
  description = "The list of elastic public IPs"
}
