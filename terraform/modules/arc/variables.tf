variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_repository_url" {
  description = "Repository URL the runners register against"
  type        = string
}

variable "github_token" {
  description = "PAT (repo scope) for runner registration. Supplied via TF_VAR, never committed."
  type        = string
  sensitive   = true
}

variable "runner_role_arn" {
  description = "IRSA role for runner pods (iam module output runner_role_arn)"
  type        = string
}

variable "runner_scale_set_name" {
  description = "Scale set name - this is the `runs-on` label CD jobs target"
  type        = string
  default     = "arc-cd"
}

variable "max_runners" {
  description = "Upper bound on concurrent runner pods"
  type        = number
  default     = 3
}
