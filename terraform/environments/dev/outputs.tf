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

output "eks_cluster_name" {
  description = "EKS cluster name (used by CI verification and kubectl config)"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA roles (Issue #10)"
  value       = module.eks.oidc_provider_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL (docker push target, Helm image.repository)"
  value       = module.ecr.repository_url
}
