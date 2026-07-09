variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
  default     = "varonis-restaurant-api"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "arc_github_token" {
  description = <<-EOT
    GitHub PAT (repo scope) for ARC runner registration. Supply via
    TF_VAR_arc_github_token (local shell or GitHub Actions secret) —
    never in a committed tfvars file.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}
