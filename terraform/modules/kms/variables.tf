variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "purpose" {
  description = "What this key encrypts (e.g. data, logs) - used in the alias; one key per purpose"
  type        = string
}

variable "allow_cloudwatch_logs" {
  description = "Grant the CloudWatch Logs service use of this key (required for encrypted log groups)"
  type        = bool
  default     = false
}

variable "deletion_window_in_days" {
  description = "Recovery window before a scheduled key deletion becomes final (7-30)"
  type        = number
  default     = 7

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}
