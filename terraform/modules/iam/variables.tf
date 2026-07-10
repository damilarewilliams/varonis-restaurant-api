variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# ---- EKS / IRSA inputs -----------------------------------------------------

variable "cluster_name" {
  description = "EKS cluster name (for the runner access entry)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (eks module output)"
  type        = string
}

variable "oidc_provider_url" {
  description = "Cluster OIDC issuer URL without https:// (eks module output)"
  type        = string
}

variable "dynamodb_table_arns" {
  description = "Table ARNs the API pod may read"
  type        = list(string)
}

variable "dynamodb_kms_key_arn" {
  description = "CMK encrypting the DynamoDB table - the API role needs kms:Decrypt on it to read the table"
  type        = string
}

variable "api_namespace" {
  description = "Namespace of the API service account"
  type        = string
  default     = "restaurant-api"
}

variable "api_service_account" {
  description = "Service account name the API pod runs as"
  type        = string
  default     = "restaurant-api"
}

variable "runner_namespace" {
  description = "Namespace of the ARC runner service account"
  type        = string
  default     = "arc-runners"
}

variable "runner_service_account" {
  description = "Service account name ARC runner pods run as"
  type        = string
  default     = "arc-runner"
}

# ---- GitHub OIDC inputs ----------------------------------------------------

variable "github_repository" {
  description = "GitHub repo (owner/name) allowed to assume the CI roles"
  type        = string
}

variable "terraform_plan_environment" {
  description = "Unprotected GitHub Environment whose jobs may run terraform plan"
  type        = string
  default     = "dev-infra-plan"
}

variable "terraform_apply_environment" {
  description = "GitHub Environment name whose jobs may assume the Terraform role (plan/apply gate, Issue #15)"
  type        = string
  default     = "dev-infra"
}
