output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (load balancers, NAT gateways)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EKS nodes, pods)"
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables (for additional gateway endpoints)"
  value       = aws_route_table.private[*].id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateway(s) - useful for external allowlists"
  value       = aws_eip.nat[*].public_ip
}
