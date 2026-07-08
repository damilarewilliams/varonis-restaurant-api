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
