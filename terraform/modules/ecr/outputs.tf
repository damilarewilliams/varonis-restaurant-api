output "repository_url" {
  description = "Full repository URL - used by docker push and Helm values (image.repository)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "Repository ARN - used by IAM policies (Issue #10)"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Repository name"
  value       = aws_ecr_repository.this.name
}
