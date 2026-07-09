variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to span (public+private subnet pair per AZ)"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4 (EKS requires at least 2)."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    true  = one shared NAT gateway (cheap, dev): AZ-a failure cuts egress everywhere.
    false = one NAT gateway per AZ (production): AZ-fault-isolated egress.
    Cost driver: each NAT gateway is ~$32/month + data processing.
  EOT
  type        = bool
  default     = false
}

variable "enable_interface_endpoints" {
  description = <<-EOT
    Create interface VPC endpoints (ECR api/dkr, CloudWatch Logs) so image
    pulls and log shipping stay on the AWS backbone instead of traversing
    NAT. Gateway endpoints (S3, DynamoDB) are free and always created.
    Interface endpoints bill per-hour per-AZ — this flag lets dev opt out.
  EOT
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = <<-EOT
    EKS cluster name for the kubernetes.io/cluster/<name> subnet tags used
    by load balancer subnet discovery. Passed as a plain string (not a
    module reference) to avoid a networking->eks dependency cycle; the name
    is deterministic: <project>-<environment>.
  EOT
  type        = string
  default     = ""
}
