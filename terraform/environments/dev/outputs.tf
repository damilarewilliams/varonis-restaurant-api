# Environment outputs — consumed by CI (infrastructure verification
# step) and by engineers. Populated as modules are enabled.

output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers)"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes)"
  value       = module.networking.private_subnet_ids
}

output "nat_public_ips" {
  description = "NAT gateway public IPs"
  value       = module.networking.nat_public_ips
}
