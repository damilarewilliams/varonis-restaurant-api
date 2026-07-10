variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "kms_key_arn" {
  description = "Logs CMK (kms module with allow_cloudwatch_logs = true)"
  type        = string
}

variable "retention_in_days" {
  description = "Log retention — logs are sensitive; unbounded retention is unbounded exposure (and cost)"
  type        = number
  default     = 30
}

variable "oidc_provider_arn" {
  description = "Cluster OIDC provider ARN (for the log shipper IRSA role)"
  type        = string
}

variable "oidc_provider_url" {
  description = "Cluster OIDC issuer URL without https://"
  type        = string
}

variable "shipper_namespace" {
  description = "Namespace of the log shipper (Fluent Bit DaemonSet)"
  type        = string
  default     = "logging"
}

variable "shipper_service_account" {
  description = "Service account the log shipper runs as"
  type        = string
  default     = "fluent-bit"
}

variable "error_alarm_threshold" {
  description = "ERROR log lines per 5 minutes before the alarm fires"
  type        = number
  default     = 5
}

variable "alarm_actions" {
  description = "Actions (e.g. SNS topic ARNs) for the error alarm; empty = visible in console only"
  type        = list(string)
  default     = []
}
