# Environment outputs - consumed by CI (infrastructure verification
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

output "dynamodb_table_name" {
  description = "Restaurants table name (app env var APP_DYNAMODB_TABLE)"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "Restaurants table ARN (IRSA policy scope, Issue #10)"
  value       = module.dynamodb.table_arn
}

output "api_irsa_role_arn" {
  description = "IRSA role for the API ServiceAccount annotation (Helm values)"
  value       = module.iam.api_role_arn
}

output "runner_irsa_role_arn" {
  description = "IRSA role for the ARC runner ServiceAccount annotation"
  value       = module.iam.runner_role_arn
}

output "gha_delivery_role_arn" {
  description = "CI role for image push (set as GitHub Actions variable)"
  value       = module.iam.gha_delivery_role_arn
}

output "gha_terraform_role_arn" {
  description = "CI role for terraform plan/apply (set as GitHub Actions variable)"
  value       = module.iam.gha_terraform_role_arn
}

output "app_log_group_name" {
  description = "Application log group (Fluent Bit output destination)"
  value       = module.logging.app_log_group_name
}

output "log_shipper_role_arn" {
  description = "IRSA role for the Fluent Bit ServiceAccount annotation"
  value       = module.logging.shipper_role_arn
}

output "argocd_application_name" {
  description = "ArgoCD Application name (CD verification: argocd app wait <name>)"
  value       = module.argocd.application_name
}
