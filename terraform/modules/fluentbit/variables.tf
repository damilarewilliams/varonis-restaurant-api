variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "Region CloudWatch Logs lives in"
  type        = string
}

variable "log_group_name" {
  description = "Destination log group (logging module output app_log_group_name)"
  type        = string
}

variable "shipper_role_arn" {
  description = "Write-only IRSA role (logging module output shipper_role_arn)"
  type        = string
}

variable "namespace" {
  description = "Namespace for the DaemonSet - must match the IRSA trust policy"
  type        = string
  default     = "logging"
}

variable "service_account" {
  description = "Service account name - must match the IRSA trust policy"
  type        = string
  default     = "fluent-bit"
}

variable "app_namespace" {
  description = "Namespace whose container logs are shipped"
  type        = string
  default     = "restaurant-api"
}
