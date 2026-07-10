output "api_role_arn" {
  description = "IRSA role for the API pod - annotate its ServiceAccount with this (Helm values)"
  value       = aws_iam_role.api.arn
}

output "runner_role_arn" {
  description = "IRSA role for ARC runner pods - annotate the runner ServiceAccount"
  value       = aws_iam_role.runner.arn
}

output "gha_delivery_role_arn" {
  description = "Role CI assumes to push images (GitHub Actions vars: AWS_DELIVERY_ROLE)"
  value       = aws_iam_role.gha_delivery.arn
}

output "gha_terraform_role_arn" {
  description = "Role CI assumes for terraform plan/apply (GitHub Actions vars: AWS_TERRAFORM_ROLE)"
  value       = aws_iam_role.gha_terraform.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
