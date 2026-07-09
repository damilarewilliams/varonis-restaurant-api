variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "table_suffix" {
  description = "Table name suffix; full name = <project>-<environment>-<suffix>"
  type        = string
  default     = "restaurants"
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for encryption at rest (kms module output)"
  type        = string
}

variable "enable_point_in_time_recovery" {
  description = "Continuous backups with 35-day point-in-time restore"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block table deletion until explicitly disabled"
  type        = bool
  default     = true
}
