variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "max_image_count" {
  description = "Tagged images to retain (rollback window); older ones expire"
  type        = number
  default     = 20
}
